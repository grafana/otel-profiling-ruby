package integrationtest

import (
	"bytes"
	"context"
	"fmt"
	"net/http"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"pyroscope-otel-integration-test/api/querier"
	"pyroscope-otel-integration-test/dockertest"
	"pyroscope-otel-integration-test/pyroscope/model"
	"pyroscope-otel-integration-test/require"
)

const pyroscopeImage = "grafana/pyroscope:1.18.0@sha256:e7edae4fd99dbb8695a1e03d7db96ab247630cf83842407908922b2f66aafc6a"

const cpuProfileType = "process_cpu:cpu:nanoseconds:cpu:nanoseconds"

func startPyroscope(t *testing.T, net *dockertest.Network) string {
	t.Helper()
	t.Log("starting pyroscope...")
	c := dockertest.StartContainer(t, dockertest.ContainerRequest{
		Image:          pyroscopeImage,
		ExposedPorts:   []string{"4040/tcp"},
		Network:        net.Name,
		NetworkAliases: []string{"pyroscope"},
		WaitFor:        dockertest.WaitForHTTP("/ready", "4040/tcp", 60*time.Second),
	})
	return fmt.Sprintf("http://%s", c.HostPort(t, "4040/tcp"))
}

func buildAppImage(t *testing.T, rubyVersion string) string {
	t.Helper()
	tag := fmt.Sprintf("pyroscope-otel-ruby-itest-%s:latest", rubyVersion)
	t.Logf("building app image %s ...", tag)
	dockertest.BuildImage(t, dockertest.BuildRequest{
		Context:    repoRoot(),
		Dockerfile: filepath.Join(repoRoot(), "integration-test", "app", "Dockerfile"),
		Platform:   "linux/amd64",
		Tag:        tag,
		BuildArgs: map[string]string{
			"RUBY_VERSION": rubyVersion,
		},
	})
	return tag
}

func startApp(t *testing.T, net *dockertest.Network, image, svcName string) {
	t.Helper()
	t.Logf("starting app %s (service_name=%s) ...", image, svcName)
	dockertest.StartContainer(t, dockertest.ContainerRequest{
		Image:          image,
		Platform:       "linux/amd64",
		Network:        net.Name,
		NetworkAliases: []string{"rideshare"},
		Env: map[string]string{
			"PYROSCOPE_APPLICATION_NAME": svcName,
			"PYROSCOPE_SERVER_ADDRESS":   "http://pyroscope:4040",
			"REGION":                     "us-east",
		},
	})
}

func queryProfile(t *testing.T, pyroscopeURL, labelSelector string) (string, error) {
	t.Helper()
	qc := querier.NewClient(http.DefaultClient, pyroscopeURL)

	to := time.Now()
	from := to.Add(-time.Hour)
	maxNodes := int64(65536)
	resp, err := qc.SelectMergeStacktraces(context.Background(),
		&querier.SelectMergeStacktracesRequest{
			ProfileTypeID: cpuProfileType,
			Start:         from.UnixMilli(),
			End:           to.UnixMilli(),
			LabelSelector: labelSelector,
			MaxNodes:      &maxNodes,
			Format:        querier.ProfileFormat_PROFILE_FORMAT_TREE,
		})
	if err != nil {
		return "", err
	}
	if len(resp.Tree) == 0 {
		return "", nil
	}
	tt, err := model.UnmarshalTree(resp.Tree)
	if err != nil {
		return "", err
	}
	buf := bytes.NewBuffer(nil)
	tt.WriteCollapsed(buf)
	return buf.String(), nil
}

type spanCheck struct {
	// span is the OpenTelemetry span name the SpanProcessor attaches as the
	// pyroscope "span" label.
	span string
	// mustContain frames that have to appear in the span-scoped profile.
	//
	// Note: we only assert positive containment. A non-empty profile for
	// {span="<name>"} already proves the SpanProcessor labels profiles per
	// span (without the label the query would return nothing). We avoid
	// negative ("must not contain") assertions because the CPU profiler can
	// attribute a sample taken at a span boundary to the adjacent span,
	// which would make such assertions flaky.
	mustContain []string
}

// TestSpanProfiles verifies that Pyroscope::Otel::SpanProcessor labels CPU
// profiles with the OpenTelemetry span name, so that profiling data can be
// queried per span.
func TestSpanProfiles(t *testing.T) {
	net := dockertest.CreateNetwork(t)

	pyroscopeURL := startPyroscope(t, net)
	t.Logf("pyroscope URL: %s", pyroscopeURL)

	image := buildAppImage(t, envRubyVersion())
	svcName := serviceName()
	startApp(t, net, image, svcName)

	checks := []spanCheck{
		{
			span:        "BikeHandler",
			mustContain: []string{"find_nearest_vehicle"},
		},
		{
			span:        "CarHandler",
			mustContain: []string{"find_nearest_vehicle", "check_driver_availability"},
		},
	}

	for _, check := range checks {
		check := check
		t.Run(check.span, func(t *testing.T) {
			labelSelector := fmt.Sprintf(`{service_name="%s",span="%s"}`, svcName, check.span)
			var lastCollapsed string
			var lastErr error
			ok := require.Eventually(t, func() bool {
				lastCollapsed, lastErr = queryProfile(t, pyroscopeURL, labelSelector)
				if lastErr != nil {
					t.Logf("[%s] query error: %s", check.span, lastErr)
					return false
				}
				if lastCollapsed == "" {
					t.Logf("[%s] empty profile", check.span)
					return false
				}
				for _, f := range check.mustContain {
					if !strings.Contains(lastCollapsed, f) {
						t.Logf("[%s] frame %q not found yet", check.span, f)
						return false
					}
				}
				return true
			}, 3*time.Minute, 5*time.Second)

			if !ok {
				if lastErr != nil {
					t.Logf("[%s] last error: %s", check.span, lastErr)
				}
				t.Logf("[%s] last collapsed profile:\n%s", check.span, lastCollapsed)
				t.FailNow()
			}
		})
	}
}

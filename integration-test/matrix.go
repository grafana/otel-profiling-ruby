package integrationtest

import (
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

func envOrDefault(key, defaultValue string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return defaultValue
}

func envRubyVersion() string { return envOrDefault("RUBY_VERSION", "3.3.9") }

// serviceName returns a unique pyroscope application name per test run so that
// profiles from different runs do not collide in a shared pyroscope instance.
func serviceName() string {
	return fmt.Sprintf("rideshare.ruby.app.%d", time.Now().UnixNano())
}

func repoRoot() string {
	_, filename, _, _ := runtime.Caller(0)
	return filepath.Dir(filepath.Dir(filename))
}

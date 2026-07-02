package tools

import (
	"context"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func newWeatherServers(t *testing.T, geocodeHits bool) (geocode, forecast *httptest.Server) {
	t.Helper()
	geocode = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !geocodeHits {
			w.Write([]byte(`{"results":[]}`))
			return
		}
		w.Write([]byte(`{"results":[{"name":"Tokyo","country_code":"JP","latitude":35.69,"longitude":139.69}]}`))
	}))
	forecast = httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Write([]byte(`{
			"current":{"temperature_2m":18.2,"apparent_temperature":17.1,"relative_humidity_2m":62,"weather_code":2,"wind_speed_10m":12.3},
			"daily":{"weather_code":[61,0],"temperature_2m_max":[21.4,19.0],"temperature_2m_min":[14.2,13.1],"precipitation_probability_max":[40,10]}
		}`))
	}))
	t.Cleanup(geocode.Close)
	t.Cleanup(forecast.Close)
	return geocode, forecast
}

func testWeatherAPI(defaultPlace, geocodeURL, forecastURL string) *weatherAPI {
	return &weatherAPI{
		http:         &http.Client{Timeout: 2 * time.Second},
		geocodeBase:  geocodeURL,
		forecastBase: forecastURL,
		defaultPlace: defaultPlace,
		geoCache:     map[string]geoPlace{},
	}
}

func TestWeatherGet(t *testing.T) {
	geo, fc := newWeatherServers(t, true)
	api := testWeatherAPI("", geo.URL, fc.URL)

	out, err := api.get(context.Background(), map[string]any{"place": "Tokyo"})
	if err != nil {
		t.Fatalf("get: %v", err)
	}
	for _, want := range []string{
		"Weather for Tokyo (JP):",
		"now: 18.2°C (feels 17.1°C), partly cloudy, humidity 62%, wind 12.3 km/h",
		"today: 14–21°C, rain probability 40%, rain",
		"tomorrow: 13–19°C, rain probability 10%, clear sky",
	} {
		if !strings.Contains(out, want) {
			t.Errorf("missing %q in:\n%s", want, out)
		}
	}
}

func TestWeatherGetDefaultPlaceAndErrors(t *testing.T) {
	geo, fc := newWeatherServers(t, true)
	api := testWeatherAPI("Tokyo", geo.URL, fc.URL)

	if out, err := api.get(context.Background(), nil); err != nil || !strings.Contains(out, "Weather for Tokyo") {
		t.Fatalf("default place: %q, %v", out, err)
	}

	noDefault := testWeatherAPI("", geo.URL, fc.URL)
	if out, _ := noDefault.get(context.Background(), nil); !strings.Contains(out, "error: no place given") {
		t.Fatalf("no place: %q", out)
	}

	misses, fc2 := newWeatherServers(t, false)
	unknown := testWeatherAPI("", misses.URL, fc2.URL)
	if out, _ := unknown.get(context.Background(), map[string]any{"place": "Atlantis"}); !strings.Contains(out, `error: could not find a place named "Atlantis"`) {
		t.Fatalf("unknown place: %q", out)
	}
}

func TestWeatherGeocodeCache(t *testing.T) {
	calls := 0
	geo := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		w.Write([]byte(`{"results":[{"name":"Tokyo","country_code":"JP","latitude":35.69,"longitude":139.69}]}`))
	}))
	t.Cleanup(geo.Close)
	_, fc := newWeatherServers(t, true)
	api := testWeatherAPI("", geo.URL, fc.URL)

	for i := 0; i < 3; i++ {
		if _, err := api.get(context.Background(), map[string]any{"place": "tokyo"}); err != nil {
			t.Fatalf("get %d: %v", i, err)
		}
	}
	if calls != 1 {
		t.Fatalf("geocode should be cached, got %d calls", calls)
	}
}

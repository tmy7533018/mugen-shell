package tools

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/url"
	"strings"
	"sync"
	"time"
)

// weatherAPI talks to Open-Meteo (free, no API key). Geocoding results are
// cached per place for the process lifetime — city coordinates don't move.
type weatherAPI struct {
	http         *http.Client
	geocodeBase  string
	forecastBase string
	defaultPlace string

	mu       sync.Mutex
	geoCache map[string]geoPlace
}

type geoPlace struct {
	Name      string  `json:"name"`
	Country   string  `json:"country_code"`
	Latitude  float64 `json:"latitude"`
	Longitude float64 `json:"longitude"`
}

// AttachWeather registers the weather_get tool. defaultPlace is used when
// the model doesn't pass one (config [weather] place).
func (r *Registry) AttachWeather(defaultPlace string) {
	api := &weatherAPI{
		http:         &http.Client{Timeout: 8 * time.Second},
		geocodeBase:  "https://geocoding-api.open-meteo.com",
		forecastBase: "https://api.open-meteo.com",
		defaultPlace: defaultPlace,
		geoCache:     map[string]geoPlace{},
	}
	r.tools = append(r.tools, Tool{
		Name:        "weather_get",
		Description: "Current weather and today/tomorrow forecast for a place (Open-Meteo).",
		Parameters: map[string]any{
			"type": "object",
			"properties": map[string]any{
				"place": map[string]any{
					"type":        "string",
					"description": "City or place name. Omit for the user's default location.",
				},
			},
		},
		readonly: true,
		kind:     "native",
		fn:       api.get,
	})
}

func (w *weatherAPI) get(ctx context.Context, args map[string]any) (string, error) {
	place, _ := args["place"].(string)
	place = strings.TrimSpace(place)
	if place == "" {
		place = w.defaultPlace
	}
	if place == "" {
		return "error: no place given and no default configured. Ask the user which city they mean (they can set a default in config.toml under [weather] place).", nil
	}

	loc, err := w.geocode(ctx, place)
	if err != nil {
		return fmt.Sprintf("error: could not find a place named %q (%v).", place, err), nil
	}

	fc, err := w.forecast(ctx, loc)
	if err != nil {
		return "", fmt.Errorf("weather lookup for %s failed: %w", loc.Name, err)
	}
	return fc, nil
}

func (w *weatherAPI) geocode(ctx context.Context, place string) (geoPlace, error) {
	key := strings.ToLower(place)
	w.mu.Lock()
	if hit, ok := w.geoCache[key]; ok {
		w.mu.Unlock()
		return hit, nil
	}
	w.mu.Unlock()

	u := w.geocodeBase + "/v1/search?count=1&language=en&format=json&name=" + url.QueryEscape(place)
	var payload struct {
		Results []geoPlace `json:"results"`
	}
	if err := w.getJSON(ctx, u, &payload); err != nil {
		return geoPlace{}, err
	}
	if len(payload.Results) == 0 {
		return geoPlace{}, fmt.Errorf("no geocoding match")
	}
	loc := payload.Results[0]
	w.mu.Lock()
	w.geoCache[key] = loc
	w.mu.Unlock()
	return loc, nil
}

func (w *weatherAPI) forecast(ctx context.Context, loc geoPlace) (string, error) {
	u := fmt.Sprintf("%s/v1/forecast?latitude=%.4f&longitude=%.4f"+
		"&current=temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m"+
		"&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max"+
		"&timezone=auto&forecast_days=2", w.forecastBase, loc.Latitude, loc.Longitude)

	var payload struct {
		Current struct {
			Temp     float64 `json:"temperature_2m"`
			Feels    float64 `json:"apparent_temperature"`
			Humidity float64 `json:"relative_humidity_2m"`
			Code     int     `json:"weather_code"`
			Wind     float64 `json:"wind_speed_10m"`
		} `json:"current"`
		Daily struct {
			Code     []int     `json:"weather_code"`
			TempMax  []float64 `json:"temperature_2m_max"`
			TempMin  []float64 `json:"temperature_2m_min"`
			RainProb []float64 `json:"precipitation_probability_max"`
		} `json:"daily"`
	}
	if err := w.getJSON(ctx, u, &payload); err != nil {
		return "", err
	}

	var b strings.Builder
	where := loc.Name
	if loc.Country != "" {
		where += " (" + loc.Country + ")"
	}
	fmt.Fprintf(&b, "Weather for %s:\n", where)
	fmt.Fprintf(&b, "now: %.1f°C (feels %.1f°C), %s, humidity %.0f%%, wind %.1f km/h\n",
		payload.Current.Temp, payload.Current.Feels, wmoText(payload.Current.Code),
		payload.Current.Humidity, payload.Current.Wind)
	labels := []string{"today", "tomorrow"}
	for i, label := range labels {
		if i >= len(payload.Daily.Code) || i >= len(payload.Daily.TempMax) ||
			i >= len(payload.Daily.TempMin) || i >= len(payload.Daily.RainProb) {
			break
		}
		fmt.Fprintf(&b, "%s: %.0f–%.0f°C, rain probability %.0f%%, %s\n",
			label, payload.Daily.TempMin[i], payload.Daily.TempMax[i],
			payload.Daily.RainProb[i], wmoText(payload.Daily.Code[i]))
	}
	return strings.TrimSuffix(b.String(), "\n"), nil
}

func (w *weatherAPI) getJSON(ctx context.Context, u string, out any) error {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return err
	}
	resp, err := w.http.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return json.NewDecoder(resp.Body).Decode(out)
}

// wmoText maps WMO weather interpretation codes to short descriptions.
func wmoText(code int) string {
	switch {
	case code == 0:
		return "clear sky"
	case code == 1:
		return "mostly clear"
	case code == 2:
		return "partly cloudy"
	case code == 3:
		return "overcast"
	case code == 45 || code == 48:
		return "fog"
	case code >= 51 && code <= 57:
		return "drizzle"
	case code >= 61 && code <= 65:
		return "rain"
	case code == 66 || code == 67:
		return "freezing rain"
	case code >= 71 && code <= 77:
		return "snow"
	case code >= 80 && code <= 82:
		return "rain showers"
	case code == 85 || code == 86:
		return "snow showers"
	case code >= 95:
		return "thunderstorm"
	default:
		return fmt.Sprintf("weather code %d", code)
	}
}

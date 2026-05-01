package context

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/tmy7533018/mugen-ai/internal/config"
)

// Build returns a context string to prepend to the system prompt.
func Build(cfg config.Context) string {
	var parts []string

	parts = append(parts, timeInfo(cfg.Locale))

	if cfg.City != "" {
		if w := weather(cfg.City); w != "" {
			parts = append(parts, w)
		}
	}

	if len(parts) == 0 {
		return ""
	}
	return "\n\n[Current info]\n" + strings.Join(parts, "\n")
}

func timeInfo(locale string) string {
	now := time.Now()
	if locale == "ja" {
		weekdays := []string{"日", "月", "火", "水", "木", "金", "土"}
		return fmt.Sprintf("Date: %s (%s) %s",
			now.Format("2006-01-02"),
			weekdays[now.Weekday()],
			now.Format("15:04 MST"))
	}
	return fmt.Sprintf("Date: %s %s",
		now.Format("2006-01-02 Mon"),
		now.Format("15:04 MST"))
}

func weather(city string) string {
	client := &http.Client{Timeout: 3 * time.Second}
	resp, err := client.Get("https://wttr.in/" + city + "?format=j1")
	if err != nil {
		return ""
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return ""
	}

	var data struct {
		Current []struct {
			TempC     string                   `json:"temp_C"`
			Desc      []map[string]string      `json:"weatherDesc"`
			Humidity  string                   `json:"humidity"`
			FeelsLike string                   `json:"FeelsLikeC"`
		} `json:"current_condition"`
		Weather []struct {
			MaxTemp string `json:"maxtempC"`
			MinTemp string `json:"mintempC"`
		} `json:"weather"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&data); err != nil || len(data.Current) == 0 {
		return ""
	}

	c := data.Current[0]
	desc := ""
	if len(c.Desc) > 0 {
		desc = c.Desc[0]["value"]
	}

	result := fmt.Sprintf("Weather in %s: %s°C (feels %s°C), %s, humidity %s%%",
		city, c.TempC, c.FeelsLike, desc, c.Humidity)
	if len(data.Weather) > 0 {
		w := data.Weather[0]
		result += fmt.Sprintf(", high %s°C, low %s°C", w.MaxTemp, w.MinTemp)
	}
	return result
}

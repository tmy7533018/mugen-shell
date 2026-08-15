package cmd

import (
	"encoding/json"
	"fmt"
	"os"
	"time"

	"github.com/spf13/cobra"
	"github.com/tmy7533018/mugen-ai/internal/calendar"
)

var calendarCmd = &cobra.Command{
	Use:   "calendar",
	Short: "Calendar event storage for the shell's calendar module",
}

// Every subcommand answers in JSON on stdout, which is what the QML parses.
func emit(v any) error {
	raw, err := json.Marshal(v)
	if err != nil {
		return err
	}
	fmt.Println(string(raw))
	return nil
}

func withStore(fn func(*calendar.Store) error) error {
	store, err := calendar.Open("")
	if err != nil {
		emitError(err)
		return err
	}
	defer store.Close()

	if err := fn(store); err != nil {
		emitError(err)
		return err
	}
	return nil
}

func emitError(err error) {
	raw, _ := json.Marshal(map[string]any{"error": err.Error(), "ok": false})
	fmt.Fprintln(os.Stderr, string(raw))
}

var calendarInitCmd = &cobra.Command{
	Use:   "init",
	Short: "Create the database and import any legacy events.json",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return withStore(func(s *calendar.Store) error {
			return emit(map[string]any{"db": s.Path(), "ok": true})
		})
	},
	SilenceUsage: true,
}

var calendarListRangeCmd = &cobra.Command{
	Use:   "list-range",
	Short: "List events between two YYYY-MM-DD dates, inclusive",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		start, _ := cmd.Flags().GetString("start")
		end, _ := cmd.Flags().GetString("end")
		return withStore(func(s *calendar.Store) error {
			events, err := s.ListRange(start, end)
			if err != nil {
				return err
			}
			return emit(map[string]any{"events": events})
		})
	},
	SilenceUsage: true,
}

var calendarListTodayCmd = &cobra.Command{
	Use:   "list-today",
	Short: "List today's events",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return withStore(func(s *calendar.Store) error {
			events, err := s.ListToday()
			if err != nil {
				return err
			}
			return emit(map[string]any{"events": events})
		})
	},
	SilenceUsage: true,
}

var calendarAddCmd = &cobra.Command{
	Use:   "add",
	Short: "Insert an event and print its id",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		date, _ := cmd.Flags().GetString("date")
		title, _ := cmd.Flags().GetString("title")
		at, _ := cmd.Flags().GetString("time")
		return withStore(func(s *calendar.Store) error {
			id, err := s.Add(date, at, title)
			if err != nil {
				return err
			}
			return emit(map[string]any{"id": id, "ok": true})
		})
	},
	SilenceUsage: true,
}

var calendarDeleteCmd = &cobra.Command{
	Use:   "delete",
	Short: "Delete an event by id",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		id, _ := cmd.Flags().GetString("id")
		return withStore(func(s *calendar.Store) error {
			n, err := s.Delete(id)
			if err != nil {
				return err
			}
			return emit(map[string]any{"deleted": n, "ok": true})
		})
	},
	SilenceUsage: true,
}

var calendarUpdateCmd = &cobra.Command{
	Use:   "update",
	Short: "Update an event's title and time",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		id, _ := cmd.Flags().GetString("id")
		title, _ := cmd.Flags().GetString("title")
		at, _ := cmd.Flags().GetString("time")
		return withStore(func(s *calendar.Store) error {
			n, err := s.Update(id, title, at)
			if err != nil {
				return err
			}
			return emit(map[string]any{"updated": n, "ok": true})
		})
	},
	SilenceUsage: true,
}

var calendarNotifyCmd = &cobra.Command{
	Use:   "notify",
	Short: "Fire desktop notifications for today's events that are due",
	Args:  cobra.NoArgs,
	RunE: func(cmd *cobra.Command, args []string) error {
		return calendar.Notify(time.Now())
	},
	SilenceUsage: true,
}

func init() {
	calendarListRangeCmd.Flags().String("start", "", "range start date YYYY-MM-DD")
	calendarListRangeCmd.Flags().String("end", "", "range end date YYYY-MM-DD")
	calendarListRangeCmd.MarkFlagRequired("start")
	calendarListRangeCmd.MarkFlagRequired("end")

	calendarAddCmd.Flags().String("date", "", "event date YYYY-MM-DD")
	calendarAddCmd.Flags().String("time", "", "event time HH:MM, empty for all-day")
	calendarAddCmd.Flags().String("title", "", "event title")
	calendarAddCmd.MarkFlagRequired("date")
	calendarAddCmd.MarkFlagRequired("title")

	calendarDeleteCmd.Flags().String("id", "", "event id")
	calendarDeleteCmd.MarkFlagRequired("id")

	calendarUpdateCmd.Flags().String("id", "", "event id")
	calendarUpdateCmd.Flags().String("title", "", "new title")
	calendarUpdateCmd.Flags().String("time", "", "new time HH:MM, empty for all-day")
	calendarUpdateCmd.MarkFlagRequired("id")
	calendarUpdateCmd.MarkFlagRequired("title")

	for _, c := range []*cobra.Command{
		calendarInitCmd, calendarListRangeCmd, calendarListTodayCmd,
		calendarAddCmd, calendarDeleteCmd, calendarUpdateCmd, calendarNotifyCmd,
	} {
		calendarCmd.AddCommand(c)
	}
	rootCmd.AddCommand(calendarCmd)
}

// Package attach reads local files into a turn: images as base64, text inline.
package attach

import (
	"encoding/base64"
	"fmt"
	"mime"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"unicode/utf8"

	"github.com/tmy7533018/mugen-ai/internal/provider"
)

const (
	MaxBytes      = 10 << 20
	MaxTextBytes  = 64 << 10
	MaxPerMessage = 4
)

var supportedImages = map[string]bool{
	"image/png":  true,
	"image/jpeg": true,
	"image/gif":  true,
	"image/webp": true,
}

type Document struct {
	Name      string
	Content   string
	Truncated bool
}

type Attachments struct {
	Images    []provider.Image
	Documents []Document
}

// Prompt appends the documents after the caller's own words.
func (a Attachments) Prompt(content string) string {
	if len(a.Documents) == 0 {
		return content
	}
	var b strings.Builder
	b.WriteString(content)
	for _, d := range a.Documents {
		if b.Len() > 0 {
			b.WriteString("\n\n")
		}
		fmt.Fprintf(&b, "[attached file: %s]\n```\n%s\n```", d.Name, d.Content)
		if d.Truncated {
			fmt.Fprintf(&b, "\n(truncated to the first %d KB)", MaxTextBytes>>10)
		}
	}
	return b.String()
}

func (a Attachments) Empty() bool {
	return len(a.Images) == 0 && len(a.Documents) == 0
}

// Load rejects the whole set on the first bad path.
func Load(paths []string) (Attachments, error) {
	var out Attachments
	if len(paths) > MaxPerMessage {
		return out, fmt.Errorf("too many attachments: %d (max %d)", len(paths), MaxPerMessage)
	}
	for _, p := range paths {
		img, doc, err := load(p)
		if err != nil {
			return Attachments{}, err
		}
		if doc != nil {
			out.Documents = append(out.Documents, *doc)
			continue
		}
		out.Images = append(out.Images, *img)
	}
	return out, nil
}

func LoadBestEffort(paths []string) Attachments {
	var out Attachments
	for _, p := range paths {
		img, doc, err := load(p)
		if err != nil {
			continue
		}
		if doc != nil {
			out.Documents = append(out.Documents, *doc)
			continue
		}
		out.Images = append(out.Images, *img)
	}
	return out
}

func load(path string) (*provider.Image, *Document, error) {
	if !filepath.IsAbs(path) {
		return nil, nil, fmt.Errorf("attachment path must be absolute: %q", path)
	}
	info, err := os.Stat(path)
	if err != nil {
		return nil, nil, fmt.Errorf("attachment %q: %w", path, err)
	}
	if !info.Mode().IsRegular() {
		return nil, nil, fmt.Errorf("attachment %q is not a regular file", path)
	}
	if info.Size() > MaxBytes {
		return nil, nil, fmt.Errorf("attachment %q is %d bytes, over the %d byte limit", path, info.Size(), MaxBytes)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, nil, fmt.Errorf("attachment %q: %w", path, err)
	}

	mediaType, _, _ := mime.ParseMediaType(http.DetectContentType(data))
	if supportedImages[mediaType] {
		return &provider.Image{
			MediaType: mediaType,
			Data:      base64.StdEncoding.EncodeToString(data),
		}, nil, nil
	}
	if doc, ok := asDocument(filepath.Base(path), data); ok {
		return nil, &doc, nil
	}
	return nil, nil, fmt.Errorf("attachment %q is neither a supported image nor a text file (%s)", path, mediaType)
}

// DetectContentType calls anything unsigned octet-stream, so judge these on their bytes.
func asDocument(name string, data []byte) (Document, bool) {
	head := data
	if len(head) > MaxTextBytes {
		head = head[:MaxTextBytes]
	}
	if !utf8.Valid(head) {
		// A cut in the middle of a rune is not a reason to reject the file.
		for len(head) > 0 && !utf8.Valid(head) {
			head = head[:len(head)-1]
		}
		if len(head) == 0 {
			return Document{}, false
		}
	}
	for _, b := range head {
		if b == 0 {
			return Document{}, false
		}
	}
	return Document{
		Name:      name,
		Content:   string(head),
		Truncated: len(head) < len(data),
	}, true
}

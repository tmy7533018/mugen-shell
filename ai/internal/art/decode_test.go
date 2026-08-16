package art

import (
	"bytes"
	"encoding/binary"
	"errors"
	"hash/crc32"
	"image"
	"image/color"
	"image/png"
	"math"
	"os"
	"path/filepath"
	"testing"
)

// Transparent blue is the probe: composited onto white it yields the golden value
// for {1,1,1} below, where dropping alpha would yield {0.343, 0.343, 1.0} instead.
var compositedWhite = RGB{0.5, 0.5, 0.5}

func writePNG(t *testing.T, name string, img image.Image) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), name)
	file, err := os.Create(path)
	if err != nil {
		t.Fatalf("create: %v", err)
	}
	defer file.Close()
	if err := png.Encode(file, img); err != nil {
		t.Fatalf("encode: %v", err)
	}
	return path
}

func assertColor(t *testing.T, path string, want RGB) {
	t.Helper()
	got, err := DominantColor(path)
	if err != nil {
		t.Fatalf("DominantColor: %v", err)
	}
	const tolerance = 1e-12
	if math.Abs(got.R-want.R) > tolerance ||
		math.Abs(got.G-want.G) > tolerance ||
		math.Abs(got.B-want.B) > tolerance {
		t.Errorf("DominantColor = %v, want %v", got, want)
	}
}

func TestDominantColorCompositesTruecolorAlpha(t *testing.T) {
	img := image.NewNRGBA(image.Rect(0, 0, 20, 20))
	for y := 0; y < 20; y++ {
		for x := 0; x < 20; x++ {
			img.SetNRGBA(x, y, color.NRGBA{R: 0, G: 0, B: 255, A: 0})
		}
	}

	assertColor(t, writePNG(t, "rgba.png", img), compositedWhite)
}

func TestDominantColorCompositesPaletteTransparency(t *testing.T) {
	palette := color.Palette{
		color.NRGBA{R: 0, G: 0, B: 255, A: 0},
		color.NRGBA{R: 255, G: 255, B: 255, A: 255},
	}
	img := image.NewPaletted(image.Rect(0, 0, 20, 20), palette)
	for y := 0; y < 20; y++ {
		for x := 0; x < 20; x++ {
			img.SetColorIndex(x, y, 0)
		}
	}

	path := writePNG(t, "paletted.png", img)
	assertColor(t, path, compositedWhite)
}

func TestDominantColorPartialAlpha(t *testing.T) {
	img := image.NewNRGBA(image.Rect(0, 0, 20, 20))
	for y := 0; y < 20; y++ {
		for x := 0; x < 20; x++ {
			img.SetNRGBA(x, y, color.NRGBA{R: 255, G: 0, B: 0, A: 128})
		}
	}

	// 255 over white at A=128 stays 255; 0 lifts to 127.
	want := ensureMinLightness(RGB{R: 1.0, G: 127.0 / 255.0, B: 127.0 / 255.0})
	assertColor(t, writePNG(t, "half.png", img), want)
}

// A valid IHDR is all DecodeConfig reads, so the bomb needs no pixel data at all.
func declaredCanvasPNG(t *testing.T, width, height uint32) string {
	t.Helper()
	header := []byte("IHDR")
	header = binary.BigEndian.AppendUint32(header, width)
	header = binary.BigEndian.AppendUint32(header, height)
	header = append(header, 8, 2, 0, 0, 0)

	var out bytes.Buffer
	out.WriteString("\x89PNG\r\n\x1a\n")
	binary.Write(&out, binary.BigEndian, uint32(len(header)-len("IHDR")))
	out.Write(header)
	binary.Write(&out, binary.BigEndian, crc32.ChecksumIEEE(header))

	path := filepath.Join(t.TempDir(), "bomb.png")
	if err := os.WriteFile(path, out.Bytes(), 0o600); err != nil {
		t.Fatalf("write: %v", err)
	}
	return path
}

// Asserted against errTooLarge, not just "some error": a header-only PNG fails
// to decode anyway, so a plain non-nil check passes with the limit removed.
func TestABombIsRejectedBeforeItIsAllocated(t *testing.T) {
	path := declaredCanvasPNG(t, 65535, 65535)
	if _, err := DominantColor(path); !errors.Is(err, errTooLarge) {
		t.Fatalf("DominantColor error = %v, want %v", err, errTooLarge)
	}
	if err := TrimBars(path); err != nil {
		t.Fatalf("TrimBars: %v", err)
	}
}

func TestAnOrdinaryCanvasIsNotMistakenForABomb(t *testing.T) {
	img := image.NewNRGBA(image.Rect(0, 0, 20, 20))
	if _, err := DominantColor(writePNG(t, "small.png", img)); err != nil {
		t.Fatalf("DominantColor: %v", err)
	}
}

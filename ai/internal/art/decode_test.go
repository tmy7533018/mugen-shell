package art

import (
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

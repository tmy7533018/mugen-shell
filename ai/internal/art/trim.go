package art

import (
	"image"
	"image/color"
	"image/gif"
	"image/jpeg"
	"image/png"
	"math"
	"os"
	"path/filepath"
)

const (
	flatTolerance    = 16
	minBar           = 4
	barInsetRatio    = 0.2
	barEndInsetRatio = 0.05
)

// Only these leave bars that count as padding, never the art's own flat margin.
var frameAspects = []float64{16.0 / 9.0, 1.0}

// TrimBars rewrites path without its letterbox/pillarbox bars, and leaves the
// file alone when it finds none. Port of scripts/trim-art-bars.py.
func TrimBars(path string) error {
	file, err := os.Open(path)
	if err != nil {
		return nil
	}
	img, format, err := image.Decode(file)
	file.Close()
	if err != nil {
		return nil
	}

	bounds := img.Bounds()
	if bounds.Dx() < 8 || bounds.Dy() < 8 {
		return nil
	}

	trimmed := unpad(img)
	if trimmed.Bounds() == bounds {
		return nil
	}

	return writeInPlace(path, trimmed, format)
}

func unpad(img image.Image) image.Image {
	for _, aspect := range frameAspects {
		b := img.Bounds()
		width, height := b.Dx(), b.Dy()
		bar, boxes := barBoxes(width, height, aspect)
		if bar < minBar {
			continue
		}

		flat := true
		for _, box := range boxes {
			if !isFlat(img, box.Add(b.Min)) {
				flat = false
				break
			}
		}
		if !flat {
			continue
		}

		if float64(width)/float64(height) > aspect {
			img = crop(img, image.Rect(bar, 0, width-bar, height).Add(b.Min))
		} else {
			img = crop(img, image.Rect(0, bar, width, height-bar).Add(b.Min))
		}
	}
	return img
}

// Inset away from the art, whose edges ring against the bars and are not flat.
func barBoxes(width, height int, aspect float64) (int, []image.Rectangle) {
	if float64(width)/float64(height) > aspect {
		bar := (width - int(pyRound(float64(height)*aspect))) / 2
		deep := max(1, int(pyRound(float64(bar)*barInsetRatio)))
		end := max(1, int(pyRound(float64(height)*barEndInsetRatio)))
		return bar, []image.Rectangle{
			image.Rect(0, end, bar-deep, height-end),
			image.Rect(width-bar+deep, end, width, height-end),
		}
	}

	bar := (height - int(pyRound(float64(width)/aspect))) / 2
	deep := max(1, int(pyRound(float64(bar)*barInsetRatio)))
	end := max(1, int(pyRound(float64(width)*barEndInsetRatio)))
	return bar, []image.Rectangle{
		image.Rect(end, 0, width-end, bar-deep),
		image.Rect(end, height-bar+deep, width-end, height),
	}
}

func isFlat(img image.Image, box image.Rectangle) bool {
	if box.Dx() < 1 || box.Dy() < 1 {
		return false
	}

	var lo, hi [3]uint8
	first := true
	for y := box.Min.Y; y < box.Max.Y; y++ {
		for x := box.Min.X; x < box.Max.X; x++ {
			r, g, b := flattenOntoWhite(img.At(x, y))
			channels := [3]uint8{r, g, b}
			if first {
				lo, hi, first = channels, channels, false
				continue
			}
			for i, v := range channels {
				if v < lo[i] {
					lo[i] = v
				}
				if v > hi[i] {
					hi[i] = v
				}
			}
		}
	}
	if first {
		return false
	}

	for i := range lo {
		if int(hi[i])-int(lo[i]) > flatTolerance {
			return false
		}
	}
	return true
}

func crop(img image.Image, box image.Rectangle) image.Image {
	out := image.NewRGBA(image.Rect(0, 0, box.Dx(), box.Dy()))
	for y := 0; y < box.Dy(); y++ {
		for x := 0; x < box.Dx(); x++ {
			r, g, b := flattenOntoWhite(img.At(box.Min.X+x, box.Min.Y+y))
			out.SetRGBA(x, y, color.RGBA{R: r, G: g, B: b, A: 255})
		}
	}
	return out
}

// Staged beside the target so a failed encode never truncates the cached art.
func writeInPlace(path string, img image.Image, format string) error {
	staged := path + ".trim"
	file, err := os.Create(staged)
	if err != nil {
		return nil
	}

	switch format {
	case "jpeg":
		err = jpeg.Encode(file, img, nil)
	case "gif":
		err = gif.Encode(file, img, nil)
	default:
		err = png.Encode(file, img)
	}
	if cerr := file.Close(); err == nil {
		err = cerr
	}
	if err != nil {
		os.Remove(staged)
		return nil
	}

	if err := os.Rename(staged, filepath.Clean(path)); err != nil {
		os.Remove(staged)
	}
	return nil
}

// Python rounds halves to even; the bar maths relies on it.
func pyRound(v float64) float64 {
	r := math.RoundToEven(v)
	return r
}

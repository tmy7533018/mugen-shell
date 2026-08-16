// Package art replaces the pillow/numpy scripts the shell used to shell out to
// for album art: dominant colour extraction and letterbox bar trimming.
package art

import (
	"image/color"
	_ "image/gif"
	_ "image/jpeg"
	_ "image/png"
	"math"
	"os"

	_ "golang.org/x/image/webp"
)

const (
	targetLuminance = 0.5
	sampleRatio     = 0.2
)

// DefaultColor is what the shell falls back to when the art yields nothing.
var DefaultColor = RGB{0.65, 0.55, 0.85}

type RGB struct {
	R, G, B float64
}

// DominantColor averages the centre of the image and lifts the result to a
// usable lightness. Faithful port of scripts/extract-color.py.
func DominantColor(path string) (RGB, error) {
	file, err := os.Open(path)
	if err != nil {
		return DefaultColor, err
	}
	defer file.Close()

	img, _, err := decodeImage(file)
	if err != nil {
		return DefaultColor, err
	}

	bounds := img.Bounds()
	width, height := bounds.Dx(), bounds.Dy()

	left := int(float64(width) * (0.5 - sampleRatio))
	top := int(float64(height) * (0.5 - sampleRatio))
	right := int(float64(width) * (0.5 + sampleRatio))
	bottom := int(float64(height) * (0.5 + sampleRatio))

	var sumR, sumG, sumB float64
	var count float64
	for y := top; y < bottom; y++ {
		for x := left; x < right; x++ {
			r, g, b := flattenOntoWhite(img.At(bounds.Min.X+x, bounds.Min.Y+y))
			sumR += float64(r)
			sumG += float64(g)
			sumB += float64(b)
			count++
		}
	}
	if count == 0 {
		return DefaultColor, nil
	}

	return ensureMinLightness(RGB{
		R: sumR / count / 255.0,
		G: sumG / count / 255.0,
		B: sumB / count / 255.0,
	}), nil
}

// PIL composites RGBA onto a white background before sampling.
func flattenOntoWhite(c color.Color) (uint8, uint8, uint8) {
	n := color.NRGBAModel.Convert(c).(color.NRGBA)
	if n.A == 255 {
		return n.R, n.G, n.B
	}
	blend := func(fg uint8) uint8 {
		return uint8(muldiv255(255, 255-n.A) + muldiv255(uint32(fg), n.A))
	}
	return blend(n.R), blend(n.G), blend(n.B)
}

func muldiv255(a uint32, b uint8) uint32 {
	t := a*uint32(b) + 128
	return ((t >> 8) + t) >> 8
}

// ITU-R BT.601 coefficients.
func luminance(c RGB) float64 {
	return 0.299*c.R + 0.587*c.G + 0.114*c.B
}

func ensureMinLightness(c RGB) RGB {
	if math.Max(c.R, math.Max(c.G, c.B)) == 0 {
		return DefaultColor
	}

	lum := luminance(c)
	h, l, s := hlsFromRGB(c)

	var lFinal, sFinal float64
	if lum < targetLuminance {
		lFinal, sFinal = adjustDarkColor(c, lum)
	} else {
		lFinal, sFinal = adjustBrightColor(lum, l, s)
	}

	return finalizeLuminance(rgbFromHLS(h, lFinal, sFinal))
}

func adjustDarkColor(c RGB, lum float64) (float64, float64) {
	scaled := c
	if lum > 0 {
		factor := math.Min(targetLuminance/lum, 3.0)
		scaled = RGB{
			R: math.Min(1.0, c.R*factor),
			G: math.Min(1.0, c.G*factor),
			B: math.Min(1.0, c.B*factor),
		}
	}

	_, _, sScaled := hlsFromRGB(scaled)

	lFinal := math.Min(0.85, targetLuminance+0.1)
	sFinal := math.Max(0.5, math.Min(1.0, sScaled*1.3))
	return lFinal, sFinal
}

func adjustBrightColor(lum, l, s float64) (float64, float64) {
	var lFinal float64
	if lum > targetLuminance*1.2 {
		lFinal = math.Max(targetLuminance-0.1, l*0.9)
	} else {
		lFinal = math.Max(targetLuminance-0.05, l)
	}

	sFinal := s
	if s < 0.9 {
		sFinal = math.Min(1.0, s*1.05)
	}
	return lFinal, sFinal
}

func finalizeLuminance(c RGB) RGB {
	lum := luminance(c)
	if math.Abs(lum-targetLuminance) > 0.15 && lum > 0 {
		factor := targetLuminance / lum
		c = RGB{
			R: math.Min(1.0, c.R*factor),
			G: math.Min(1.0, c.G*factor),
			B: math.Min(1.0, c.B*factor),
		}
	}
	return c
}

func hlsFromRGB(c RGB) (h, l, s float64) {
	maxc := math.Max(c.R, math.Max(c.G, c.B))
	minc := math.Min(c.R, math.Min(c.G, c.B))
	sumc := maxc + minc
	rangec := maxc - minc
	l = sumc / 2.0
	if minc == maxc {
		return 0.0, l, 0.0
	}

	if l <= 0.5 {
		s = rangec / sumc
	} else {
		s = rangec / (2.0 - maxc - minc)
	}

	rc := (maxc - c.R) / rangec
	gc := (maxc - c.G) / rangec
	bc := (maxc - c.B) / rangec

	switch {
	case c.R == maxc:
		h = bc - gc
	case c.G == maxc:
		h = 2.0 + rc - bc
	default:
		h = 4.0 + gc - rc
	}
	h = pymod(h/6.0, 1.0)

	return h, l, s
}

func rgbFromHLS(h, l, s float64) RGB {
	if s == 0.0 {
		return RGB{l, l, l}
	}

	var m2 float64
	if l <= 0.5 {
		m2 = l * (1.0 + s)
	} else {
		m2 = l + s - (l * s)
	}
	m1 := 2.0*l - m2

	return RGB{
		R: hueComponent(m1, m2, h+1.0/3.0),
		G: hueComponent(m1, m2, h),
		B: hueComponent(m1, m2, h-1.0/3.0),
	}
}

func hueComponent(m1, m2, hue float64) float64 {
	hue = pymod(hue, 1.0)
	switch {
	case hue < 1.0/6.0:
		return m1 + (m2-m1)*hue*6.0
	case hue < 0.5:
		return m2
	case hue < 2.0/3.0:
		return m1 + (m2-m1)*(2.0/3.0-hue)*6.0
	}
	return m1
}

// Go's % follows the dividend's sign where python's follows the divisor's.
func pymod(a, b float64) float64 {
	r := math.Mod(a, b)
	if r != 0 && (r < 0) != (b < 0) {
		r += b
	}
	return r
}

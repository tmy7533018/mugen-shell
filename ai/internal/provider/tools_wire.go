package provider

// toolsAsOpenAI renders the registry's tools in the OpenAI / Ollama
// `{type: "function", function: {...}}` shape. Gemini has its own format,
// see toolsAsGemini below.
func toolsAsOpenAI(tools []Tool) []map[string]any {
	if len(tools) == 0 {
		return nil
	}
	out := make([]map[string]any, 0, len(tools))
	for _, t := range tools {
		out = append(out, map[string]any{
			"type": "function",
			"function": map[string]any{
				"name":        t.Name,
				"description": t.Description,
				"parameters":  t.Parameters,
			},
		})
	}
	return out
}

// toolsAsGemini wraps tools into Gemini's `function_declarations` block.
func toolsAsGemini(tools []Tool) []map[string]any {
	if len(tools) == 0 {
		return nil
	}
	decls := make([]map[string]any, 0, len(tools))
	for _, t := range tools {
		decls = append(decls, map[string]any{
			"name":        t.Name,
			"description": t.Description,
			"parameters":  t.Parameters,
		})
	}
	return []map[string]any{{"function_declarations": decls}}
}

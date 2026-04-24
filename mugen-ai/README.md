# mugen-ai

AI backend for [mugen-shell](https://github.com/tmy7533018/mugen-shell). Supports [Ollama](https://ollama.com) and Google Gemini.

## Install

```sh
go install github.com/tmy7533018/mugen-ai@latest
```

Autostart via systemd:

```sh
mkdir -p ~/.config/systemd/user
cp contrib/systemd/mugen-ai.service ~/.config/systemd/user/
systemctl --user enable --now mugen-ai.service
```

## Configuration

`~/.config/mugen-ai/config.toml`:

```toml
[personality]
system_prompt = "You are a helpful desktop assistant. Be concise."

[context]
locale = "en"
city = ""

[provider.google]
model = "gemini-2.5-flash"
```

- **`city`** — enables live weather via [wttr.in](https://wttr.in). Leave empty to disable.
- **`[provider.google].model`** — enables Gemini (requires `GEMINI_API_KEY`). Omit to disable.

### Gemini API key

```sh
echo 'GEMINI_API_KEY=...' > ~/.config/mugen-ai/.env
chmod 600 ~/.config/mugen-ai/.env
systemctl --user restart mugen-ai.service
```

## Usage

```sh
mugen-ai serve   # HTTP server on :11435
mugen-ai chat    # terminal chat
```

## API

| Method | Path | Description |
|--------|------|-------------|
| POST | `/chat` | Send a message, receive SSE stream |
| DELETE | `/history` | Clear conversation history |
| GET | `/health` | Server status and active model |
| GET | `/models` | List available models |
| PUT | `/model` | Switch the active model (`{"model": "name"}`) |

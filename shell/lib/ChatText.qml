pragma Singleton
import QtQuick

QtObject {
    id: root

    function toolArgumentText(value) {
        return typeof value === "string" ? value : JSON.stringify(value)
    }

    function utf8Length(s) {
        let n = 0
        for (const ch of s) {
            const c = ch.codePointAt(0)
            n += c < 0x80 ? 1 : c < 0x800 ? 2 : c < 0x10000 ? 3 : 4
        }
        return n
    }

    // Qt fetches a markdown image target while rendering, so a model-authored URL phones home unclicked.
    function stripImages(text) {
        let prev
        do {
            prev = text
            text = text.replace(/!\[([^\]]*)\]\([^)]*\)/g, "$1")
                       .replace(/!\[([^\]]*)\]\[[^\]]*\]/g, "$1")
                       .replace(/!\[([^\]]*)\]/g, "$1")
        } while (text !== prev)
        return text
    }

    // md4c opens raw HTML (which fetches img/url() targets) at '<' + [A-Za-z/!?] but never at '<http(s)://'; a word joiner defuses it without a line break.
    function escapeRawHtml(text) {
        return text.replace(/<(?!https?:\/\/[^\x00-\x20<>]*>)(?=[a-z\/!?])/gi, "<\u2060")
    }

    // An unclosed ``` mid-stream still yields a code block, so partial code shows while it streams.
    function parseBlocks(content) {
        if (!content) return []
        let blocks = []
        let parts = content.split("```")
        for (let i = 0; i < parts.length; i++) {
            let part = parts[i]
            if (i % 2 === 0) {
                if (part.length > 0) blocks.push({ type: "text", content: root.escapeRawHtml(root.stripImages(part)) })
            } else {
                let nl = part.indexOf("\n")
                let lang = ""
                let body = part
                if (nl >= 0) {
                    let firstLine = part.substring(0, nl).trim()
                    if (/^[a-zA-Z0-9_+\-]*$/.test(firstLine)) {
                        lang = firstLine
                        body = part.substring(nl + 1)
                    }
                }
                if (body.endsWith("\n")) body = body.substring(0, body.length - 1)
                blocks.push({ type: "code", lang: lang, content: body })
            }
        }
        return blocks
    }

    // The one-line pill can't render markdown.
    function mdFlat(t) {
        return t.replace(/```[\s\S]*?```/g, " ")
                .replace(/\[([^\]]*)\]\([^)]*\)/g, "$1")
                .replace(/[`*_#>]/g, "")
                .replace(/\s*\n+\s*/g, " ")
                .replace(/[ \t]+/g, " ")
    }
}

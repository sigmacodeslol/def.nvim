# def.nvim

def.nvim is a lightweight Neovim plugin for quickly looking up word definitions, examples, synonyms, and antonyms directly in a floating window. It supports word history, favorites, random word exploration, and integrates with Telescope for a smoother experience.

---

## Features

- Lookup the definition of any word under the cursor or via input.
- Display pronunciations (IPA) and examples.
- Highlight keywords, definitions, synonyms, and antonyms in a readable floating window.
- Add words to favorites for quick reference.
- View a history of previously looked-up words.
- Fetch a random word of the day (WOTD) for vocabulary building.
- Integrates with [Telescope](https://github.com/nvim-telescope/telescope.nvim) for history and favorites search.
- Minimal dependencies — uses native Neovim APIs and Lua.

---

## Installation

### Using lazy.nvim

```lua
{
  "thesignumt/def.nvim",
  dependencies = {"nvim-telescope/telescope.nvim"},
  opts = {
    -- your opts
  },
  config = function(_, opts)
    require('def').setup(opts)
  end
}
```

### Using packer.nvim

```lua
use {
  "thesignumt/def.nvim",
  requires = {"nvim-telescope/telescope.nvim"},
  config = function()
    require("def").setup()
  end
}
```

---

## Preview

![preview](preview.png)

---

## Usage

### Lookup word under cursor

```lua
require("def").lookup("word")
```

### Prompt for a word

```lua
require("def").lookup("lookup")
```

### Word of the day (random word)

```lua
require("def").lookup("wotd")
```

### Show history

```lua
require("def").lookup("history")
```

### Show favorites

```lua
require("def").lookup("favorites")
```

---

## Keymaps in the floating window

- `q` / `<Esc>` → Close the window
- `?` → Show help keymaps
- `ga` → Add the current word to favorites
- `gA` → Remove the current word from favorites

---

## Configuration

Configure floating window dimensions in `setup()`:

```lua
require("def").setup({
  cmd = true,   -- user command :Def
  width = 80,   -- max width of floating window
  height = 40,  -- max height of floating window
})
```

These are the default configuration options.

---

## Dependencies

- Neovim 0.8+
- Lua
- `curl` command-line tool (for fetching word definitions)
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (optional but recommended)

---

## Contributing

Contributions are welcome! Submit bug reports, feature requests, or pull requests. Follow Neovim Lua best practices and maintain consistent code style.

---

## License

MIT License

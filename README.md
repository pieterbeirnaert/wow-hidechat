# HideChat (WoW Forever addon)

Hides all chat windows. Press Enter (or `/`) to type and the chat comes back
until you send or cancel. The typing bar is faded out while chat is hidden.

When someone whispers you (character or Battle.net) while chat is hidden, the
minimap button pulses pink with a counter; hover it to see who. Clicking it
shows chat and clears the alert.

Toggle with:

- the chat-bubble button on the minimap (click = toggle, drag = move)
- `/hidechat` (toggle), `/hidechat on`, `/hidechat off`, `/hidechat minimap` (show/hide the button)
- a key binding: Esc > Options > Keybindings > AddOns > "Toggle chat"

Install: copy the `HideChat` folder into `<WoW install>/_classic_.../Interface/AddOns/`
(the Forever client's own folder). Interface is 16001 (WoW Forever beta). If the addon list says "out of date" or "Incompatible", run
`/dump select(4, GetBuildInfo())` in game and put that number on the
`## Interface:` line of `HideChat.toc`, or tick "Load out of date AddOns".

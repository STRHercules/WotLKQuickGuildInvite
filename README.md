# GuildQuickInvite

A streamlined guild recruitment addon for **World of Warcraft 3.3.5**.

---

## Features

- **Right-click invites** and recruitment whispers from unit frames and chat.
- **Cooldown tracking** for invites and whispers to prevent spam.
- **Recruitment Message Manager** with save, delete, clear, and active message selection.
- **Macro generation** for the active recruitment message.
- **Invite history UI** with join/decline tracking and sortable columns.
- **12/24 hour timestamp toggle** for the history window.
- **Optional tooltip cooldown display**.
- **ElvUI skin support** when ElvUI is loaded.
- **Smooth fade-out** of the message manager when unfocused.

---

## Installation

1. Download or clone this repository.
2. Copy the `GuildQuickInvite` folder to your `Interface/AddOns` directory.
3. Restart the game or run `/reload`.

---

## Slash Commands

- `/gqi <message>` – set your default recruitment whisper.
- `/gqi` – print the current recruitment message.
- `/gqimsg` – open the recruitment message manager UI.
- `/gqihistory` – show invite history.
- `/gqisummary` – print a summary of invites.
- `/gqiclearhistory` – clear the invite history list.
- `/gqireset` – reset cooldown data.
- `/gqicooldown <minutes>` – change invite and whisper cooldowns.
- `/gqitooltip` – toggle tooltip cooldown information.
- `/gqitime` – switch between 12‑hour and 24‑hour timestamps.
- `/gqichannel <channel>` – set the chat channel for macro messages.

---

## Context Menu Integration

Right‑click a player's name or unit frame to send a guild invite or your active recruitment whisper. Options automatically respect cooldowns.

---

## Saved Variables

- `GuildQuickInviteDB` – invite cooldowns.
- `GuildQuickInviteMessages` – stored recruitment messages.
- `GuildQuickInviteActiveMessage` – currently selected message.
- `GuildQuickInviteRecruitMsg` – fallback whisper text.
- `GuildQuickInviteRecruitDB` – whisper cooldowns.
- `GQI_HistoryDB` – invite history.

---

## Compatibility

- World of Warcraft 3.3.5 (Wrath of the Lich King)
- ElvUI backport (optional)

---

## Authors

**Zach** – concept and UI design  
**ChatGPT** – scripting assistance



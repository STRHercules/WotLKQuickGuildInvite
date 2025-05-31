# 📬 GuildQuickInvite (WotLK 3.3.5 Addon)

GuildQuickInvite is a streamlined **recruitment addon for World of Warcraft 3.3.5 (Wrath of the Lich King)** that helps you easily manage guild invites, automate whispers, and organize recruitment messages—all through a slick UI with **ElvUI skin support**.

---

## ✨ Features

- ✅ **Right-click guild invite** and recruitment whisper from unit frames and the chat.
- 🧠 **Invite cooldown tracking** to prevent spam (default: 6 hours).
- 💬 **Custom recruitment messages** 
- 🖱️ **Graphical Message Manager UI**:
  - Save, delete, and set active messages
  - Clear all saved messages at once
- 🎨 **ElvUI integration** (if detected):
  - Transparent frame styling
  - Buttons, edit box, and dropdown skinned to match ElvUI
- 🎭 **Fade-out effect** when the GUI loses focus

---

## 🔧 Installation

1. Download or clone the repository.
2. Place the `GuildQuickInvite` folder in your `Interface/AddOns` directory.
3. Restart WoW or reload your UI with `/reload`.

---

## 💬 Slash Commands

- `/gqi <message>`  
  Sets your default recruitment whisper message.

- `/gqi`  
  Prints your currently set recruitment message.

- `/gqimsg`  
  Opens the recruitment message manager UI.

---

## 🖱️ Context Menu Integration

Right-click a player's unitframe or name in chat to:

- **Invite to Guild** (respects cooldowns)
- **Recruit** with your active message

---

## ⚙️ Saved Variables

The addon uses the following SavedVariables:

- `GuildQuickInviteDB` — Tracks player invite cooldowns
- `GuildQuickInviteMessages` — List of saved recruitment messages
- `GuildQuickInviteActiveMessage` — Currently selected message
- `GuildQuickInviteRecruitMsg` — Fallback whisper message from `/gqi`

---

## 🎨 ElvUI Skin Support

If ElvUI is loaded, the addon will automatically:

- Apply the `Transparent` frame template
- Skin frame, and buttons, using ElvUI's skinning module

No configuration needed — just have ElvUI enabled!

---

## 🧪 Compatibility

- ✅ World of Warcraft 3.3.5 (Wrath of the Lich King)
- ✅ ElvUI (WotLK backport version)

---

## 📌 To-Do / Ideas

- [ ] Global vs. character message profiles toggle
- [ ] Export/import message templates
- [ ] Sound cue or visual indicator when someone joins
- [ ] Welcome message toggle per invite

---

## 🧑‍💻 Authors

**Zach** (concept, UI design)  
**ChatGPT** (scripting assistant & code wrangler)

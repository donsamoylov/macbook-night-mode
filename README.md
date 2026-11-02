<p align="center">
  <img src="docs/panel.png" width="300" alt="Night Mode panel for Mac: a big on/off button and two sliders that dim the MacBook screen and keyboard backlight below the minimum">
</p>

<h1 align="center">Night Mode: make your MacBook darker than the lowest brightness</h1>

<p align="center">
  <b>Screen too bright at the lowest setting? Keyboard backlight too bright in the dark?</b><br>
  One button in the menu bar takes both below the macOS minimum, for the last hour before sleep.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-tested%20on%2027-141b2e" alt="Tested on macOS 27">
  <img src="https://img.shields.io/badge/Apple%20Silicon-MacBook-141b2e" alt="For Apple Silicon MacBooks">
  <img src="https://img.shields.io/badge/license-MIT-141b2e" alt="MIT license">
</p>

<p align="center"><a href="#по-русски">По-русски</a></p>

---

At night the lowest brightness on a MacBook is still too bright. One more press of the brightness key turns the backlight off and leaves a black screen, and macOS has nothing in between. The keyboard has the same problem: its lowest step is too bright in a dark room, and the only step below it is off.

**Night Mode** adds the missing range. Click the moon in the menu bar, press the big button, and the screen and keyboard drop below their minimum. Press it again and everything returns to where it was.

## Features

- **Dim the screen below minimum brightness.** Down to −80% from the system minimum, with the backlight still on.
- **Dim the keyboard backlight below the lowest setting.** Down to −90%, held steady at the level you pick.
- **One big on/off button.** Click the moon icon in the menu bar to open the panel.
- **Your levels are saved.** Slider positions survive restarts.
- **Everything comes back.** Turning the mode off restores your previous screen and keyboard brightness and automatic keyboard brightness.
- **A way out in the dark.** Can't see the screen? Press the brightness up key (F2) and the mode turns off.
- **Always there.** Starts at login, lives in the menu bar, no Dock icon.
- **Nothing leaves your Mac.** No network code, no account, no analytics.

## Install

Night Mode is built from source for now, there is no downloadable app yet. You need an Apple Silicon MacBook and the Xcode Command Line Tools (not full Xcode):

```bash
xcode-select --install
```

```bash
git clone https://github.com/donsamoylov/macbook-night-mode.git
```

```bash
cd macbook-night-mode && ./build.sh --install
```

This puts the app in `~/Applications/Night Mode.app` and adds a LaunchAgent, so it starts at login and comes back after a crash. No admin password is needed.

## How to use

1. Click the moon in the menu bar.
2. Press the big button.
3. Drag the sliders. The right edge is the plain system minimum, further left is darker.

The interface is in Russian for now: Ночной режим = Night Mode, Включен / Выключен = On / Off, Экран = Screen, Клавиатура = Keyboard, Выйти = Quit. Quitting keeps the app closed until your next login.

Set the levels in the room where you will use them. Both sliders start at −30%. The screen slider lowers the signal, not the light directly, so −50% is only about a fifth of the light at the minimum (an estimate for gamma 2.2), and that looks black in a lit room.

While the mode is off, the sliders only remember their position. Raising the keyboard brightness in Control Center gives the keyboard back to macOS, and the screen stays dimmed.

## Questions

### How do I make my MacBook screen darker than the lowest brightness?

macOS stops at the bottom step of the brightness keys, and below it the backlight goes off completely. Night Mode keeps the backlight on that bottom step and lowers the display output through the gamma table, so the picture gets darker and stays visible.

### How do I dim the MacBook keyboard backlight below the lowest setting?

macOS clamps any non-zero keyboard brightness to a floor, but its fades pass through the lower levels on the way to zero. Night Mode starts a fade down, reads the real level and holds it at your chosen point with slow fades. The method comes from [Lowlight](https://github.com/Isaac-Harper/lowlight).

### Isn't that what Night Shift does?

No. Night Shift and True Tone change the color of the screen, not the amount of light, and they don't touch the keyboard.

### How is it different from Lowlight or BetterDisplay?

Lowlight handles the keyboard and BetterDisplay handles displays. Night Mode does both together with one button and does nothing else. Quit Lowlight while using it, since both drive the same backlight.

### Is it safe?

Nothing is written to firmware or color profiles. The gamma change lasts only while the app runs, so if it crashes the display output returns to normal by itself. The backlight then stays at the minimum until you change it.

Other apps that change the gamma table will conflict with Night Mode, which reapplies its value every second.

### Will it work on my Mac?

It has been tested on one machine: a MacBook Pro with M5 Pro on macOS 27. The build targets Apple Silicon and macOS 14 or later, but older systems and other models are untested, and there is no Intel build. It relies on private macOS APIs, so a system update can break it. If it fails on your Mac, please [open an issue](https://github.com/donsamoylov/macbook-night-mode/issues) with your model and macOS version.

### Does it work with external monitors?

The gamma dimming applies to every connected display, and the backlight control only to the built-in one. External monitors have not been tested.

## How it works

- **Screen.** Private `DisplayServicesSetBrightness` holds the built-in panel at 1/16, the bottom step of the brightness keys. On the tested panel that is about 1 nit, and 0 means the backlight is off. `CGSetDisplayTransferByFormula` lowers the output further. Both are checked every second, so automatic brightness can't lift the screen for long.
- **Keyboard.** `KeyboardBrightnessClient` from the private CoreBrightness framework runs the fades, and the live level comes from `kbd-backlight` in the IORegistry. Automatic keyboard brightness is paused during the hold and resumed afterwards. When the keyboard dims on idle, the hold returns at the next touch.
- **Keys.** A listen-only event tap sees the brightness keys without blocking them. On the tested Mac this needed no permission prompt.

It is about 700 lines of Swift with no dependencies.

## Uninstall

Turn the mode off and press Выйти in the panel, then:

```bash
launchctl bootout gui/$UID/io.github.donsamoylov.nightmode
```

```bash
rm ~/Library/LaunchAgents/io.github.donsamoylov.nightmode.plist
```

```bash
rm -rf ~/Applications/"Night Mode.app"
```

## Credits

- The keyboard method and parts of its code come from [Lowlight](https://github.com/Isaac-Harper/lowlight) by Isaac Harper (MIT).
- The moon icon is `bedtime` from [Google Material Symbols](https://fonts.google.com/icons) (Apache 2.0).

See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Night Mode is an independent project, not affiliated with Apple.

## License

[MIT](LICENSE)

## По-русски

### Экран MacBook слишком яркий даже на минимальной яркости? Подсветка клавиатуры мешает в темноте?

Ночью минимальная яркость MacBook все равно слишком высокая. Следующее нажатие клавиши выключает подсветку совсем, и экран становится черным, а между этими шагами в macOS ничего нет. С клавиатурой то же самое: нижний шаг подсветки в темной комнате слишком яркий, а ниже только выключено.

**Night Mode** добавляет недостающий диапазон. Нажмите на луну в верхнем меню, потом на большую кнопку, и экран с подсветкой клавиатуры уйдут ниже минимума. Еще одно нажатие вернет все как было.

- **Экран темнее минимальной яркости:** до −80% от системного минимума, подсветка остается включенной.
- **Подсветка клавиатуры ниже минимума:** до −90%.
- **Положение бегунков сохраняется** и после перезапуска.
- **Выход в темноте:** клавиша прибавления яркости (F2) выключает режим, если экрана уже не видно.
- **Всегда под рукой:** запускается при входе в систему, живет в верхнем меню, значка в Dock нет.
- **Без сети:** ни учетной записи, ни аналитики.

Установка: сборка из исходников, команды в разделе [Install](#install). Нужны Mac на Apple Silicon и Command Line Tools. Проверено на MacBook Pro с M5 Pro и macOS 27, на других моделях не проверялось. Приложение использует закрытые API macOS, поэтому обновление системы может его сломать.

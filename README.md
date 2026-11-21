# Pouf

Sticky notes for macOS that can turn to dust.

**[Website and download](https://eidoslab.fr/pouf)**

Put a timer on a note. When the time is up, the note disintegrates on your screen and is gone for good.

## Features

- Floating sticky notes: write, drag, resize, five colours
- A timer per note: 10 seconds, 1, 5, 15, 30 minutes, 1 hour, or any duration
- When the timer ends, the note breaks into dust and disappears
- Notes without a timer stay until you throw them away
- Notes are saved on your Mac only, in `~/Library/Application Support/Pouf`
- A menu bar icon to add a note from anywhere

## Install

Download [`Pouf.dmg`](https://github.com/AdrienBalcioglu/pouf/releases/latest/download/Pouf.dmg), open it and drag Pouf to Applications.

The app is not notarized by Apple. If you download the DMG from the internet, macOS blocks the first launch: right-click the app, choose Open, then confirm.

## Build

```bash
./build.sh
```

It needs the Xcode Command Line Tools only, not Xcode. The result is a universal app (Apple silicon and Intel) for macOS 13 or later.

## License

[MIT](LICENSE) © 2026 Adrien Balcioglu

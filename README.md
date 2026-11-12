# Ahmod Press — Home Page

A game home page designed like a person holding today's newspaper in front of
you — the whole menu is printed on the front page. Built with Godot 4.7.

The reader picks: **PLAY**, **SHOP**, **LEVELS**, **SETTINGS** (gear), mutes
the sound, or drags the **VOLUME** slider — all printed on the paper.

## Animations & feel
- The paper drops in with a spring, settles with a cloth thud + wood creak
- Pendulum sway + breathing bob while the "reader" holds it
- Mouse parallax: paper and background shift in depth as you move the mouse
- Slow Ken Burns zoom on the background
- Buttons pop on hover (paper-flip sound), squash on press (press sound)
- Floating dust motes + cinematic vignette
- Toast notes spring out of the paper for "coming soon" actions

## Credits (all downloaded assets — nothing hand-drawn)
| Asset | Source | License |
|---|---|---|
| Hands holding a vintage newspaper (photo #4485492) | Pexels — Mohammed Alouani — https://www.pexels.com/photo/4485492/ | Pexels License (free to use) |
| Aged paper texture (photo #16557322) | Pexels — https://www.pexels.com/photo/16557322/ | Pexels License (free to use) |
| Masthead font (UnifrakturMaguntia) | Google Fonts — https://fonts.google.com/specimen/UnifrakturMaguntia | SIL OFL 1.1 |
| Body fonts (Old Standard TT, Courier Prime) | Google Fonts | SIL OFL 1.1 |
| Paper flip / cloth / creak sounds | Kenney RPG Audio — https://kenney.nl/assets/rpg-audio | CC0 |
| UI sounds (hover, press, toggle, confirm) | Kenney Interface Sounds — https://kenney.nl/assets/interface-sounds | CC0 |
| Speaker & gear icons | Pixel Art Wooden GUI v1 by Narik — https://soulofkiran.itch.io/pixel-art-wooden-gui-v1 | CC0 |

## Run
Open the project in Godot 4.7 and press Play, or:

```
Godot_v4.7.2-stable_win64.exe --path "C:\Users\LENOVO\Downloads\أحمد"
```

F11 toggles fullscreen, ESC quits. Sound settings are saved to `user://settings.cfg`.

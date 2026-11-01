<div align="center">

# THE SUBMERSION

### The sea is rising. Keep your city alive from 2026 to 2050.

*A real-time climate-survival city builder: wall out the water, or fix the climate that is flooding you.*

![Godot](https://img.shields.io/badge/Godot-4.x-478CBF?style=for-the-badge&logo=godotengine&logoColor=white)
![Language](https://img.shields.io/badge/Language-GDScript-355570?style=for-the-badge)
![Renderer](https://img.shields.io/badge/Renderer-GL%20Compatibility-5B8DEF?style=for-the-badge)
![Hackathon](https://img.shields.io/badge/GameUp%20T%C3%BCrkiye-Hackathon%202026-00A3E0?style=for-the-badge)
![COP31](https://img.shields.io/badge/COP31-Climate%20Themes-2E8B57?style=for-the-badge)

**English** · [Türkçe](README.tr.md)

[About](#-about-the-game) · [COP31 themes](#-built-for-the-cop31-themes) · [How a run works](#-how-a-run-works) · [Screenshots](#-screenshots) · [Controls](#-controls)

</div>

---

</p>

## 🌊 About the Game

**The Submersion** is a real-time city-management and survival game set between **2026 and 2050**. You govern an island city on a shrinking circle of land while the sea climbs. Every building you place changes the city's budget, power, food and mood, **and** the carbon in the atmosphere. That carbon decides how fast the water rises.

| | |
|---|---|
| **Genre** | Real-time strategy, survival & city builder (isometric 3D) |
| **Platform** | Windows (Godot export), Linux/macOS via Godot export. Runs from source on any machine that runs Godot 4 |
| **Players** | Single player |
| **Languages** | English and Turkish, switchable in Settings |
| **Made for** | The GameUp Türkiye game hackathon, built in a 48-hour development window |

### The story

> It is 2026. The climate crisis has crossed its tipping point and the sea begins to rise. You are the administrator of a city on the edge of disaster. With a limited budget and a restless population, you must stop the city from sinking, and you must keep it standing until 2050.

### The core dilemma

Every run comes down to one question:

- **Treat the symptom.** Build seawalls and defences with your money. They buy time, but walls wear down and the carbon keeps flowing, so the sea rises faster later.
- **Treat the cause.** Switch to clean energy, tax carbon, and build carbon capture. The city gets poorer and angrier in the short term (blackouts, unrest), but if CO₂ really falls, **the sea slows and can even retreat**.

### Key features

-  **Carbon drives the sea.** Your emissions set the CO₂ level (ppm); the CO₂ level sets how fast the sea rises, and it accelerates past 480 ppm. Push CO₂ under 400 ppm and the water slows, then recedes.
-  **12 buildings with real trade-offs:** houses, apartments, farms, vertical farms, markets, factories, coal plants, solar panels, wind turbines, carbon capture, forest parks, and seawalls.
-  **Vertical architecture.** Apartments and vertical farms survive floods **1.2 m higher**, and houses and farms can be **upgraded in place**.
-  **Flood forecast overlay.** Red tiles flood within about 2 years, orange within about 5. Plan before the water arrives.
-  **Living coastline.** A depth-aware water shader, shoreline foam, wet-sand tinting, storm surges, and buildings that visibly sink when lost.
-  **Policies and dilemmas.** Fossil-fuel ban, carbon tax, green subsidy, plus events such as climate refugees, heat waves, storm surges, droughts, and a COP green fund offer.
-  **Dynamic weather.** Clear, cloudy, drizzle, rain, heavy rain and thunderstorms with lightning.
-  **Six endings** with their own cinematic sequence (see below).
-  **Quality of life.** Drag-to-box-select, in-place upgrades, 3 save slots plus yearly autosave, fully rebindable keys, dismissible tips, a low-graphics mode, UI scaling, and resolution-independent mouse picking.

## Built for the COP31 Themes

The game was designed around the four hackathon themes:

| COP31 theme | How it appears in the game |
|---|---|
| **Renewable energy & sustainability** | Coal is cheap and strong but dirty. Solar and wind are clean but weaker, and wind needs high ground. Blackouts slow the whole economy and anger the people. |
| **Carbon footprint & conscious consumption** | Every building has a carbon cost. A carbon tax, green subsidy and fossil ban change what is worth building, and every choice shows up in the CO₂ curve. |
| **Oceans & seas** | Sea-level rise is the central mechanic: accelerating with CO₂, flooding land tile by tile, surging in storms, and able to recede if you clean up the atmosphere. |
| **Climate-resilient cities** | Seawalls, vertical architecture, in-place upgrades and the flood forecast teach resilience: adapt to what is coming **and** reduce what causes it. |

## How a run works

1. **Start.** You begin in 2026 with a small town. Place a few buildings in peace.
2. **Balance the city.** Keep **power**, **food**, **housing** and **jobs** healthy so that **mood** stays up. If mood reaches zero, the people revolt.
3. **Watch the sea.** Check the forecast, the CO₂ and sea graph, and the risk markers above buildings. Build seawalls, upgrade, or cut emissions.
4. **Face the dilemmas.** Every so often an event asks for a decision. Some choices cost money, some cost carbon, some cost trust.
5. **Reach 2050.** To survive you need to survive until 2050. How you get there decides which ending you see.

### Endings

| Ending | When |
|---|---|
| 🟢 **Green Future** | Reach 2050 with CO₂ **below 400 ppm** |
| 🟡 **A Costly Survival** | Reach 2050 with CO₂ between 400 and 480 ppm |
| 🔵 **Behind the Walls** | Reach 2050 with CO₂ **above 480 ppm** |
| 🟠 **The City Fades** | Reach 2050, but with fewer than 40 people or under 30% mood |
| 🔴 **People's Revolt** | Mood hits zero |
| 🌊 **The City Emptied** | Every building is lost or the population collapses |

## Screenshots

<table>
  <tr>
    <td align="center"><img src="docs/images/gameplay-2027.png" alt="Gameplay in 2027" /><br/><sub><b>2027:</b> an early town with power, farms and the build bar</sub></td>
    <td align="center"><img src="docs/images/gameplay-2042.png" alt="Gameplay in 2042 with the climate graph" /><br/><sub><b>2042:</b> the climate graph shows the 5-year forecast and buildings at risk</sub></td>
  </tr>
  <tr>
    <td align="center"><img src="docs/images/menu.png" alt="Main menu" /><br/><sub><b>Main menu:</b> a bird's-eye ice shelf, broken off from the land and melting</sub></td>
    <td align="center"><img src="docs/images/pause-menu.png" alt="Pause menu over a blurred game" /><br/><sub><b>Pause menu</b> over the blurred, frozen city</sub></td>
  </tr>
</table>


## Tech Stack

| | |
|---|---|
| **Engine** | [Godot 4](https://godotengine.org) (developed with 4.7.1), standard build |
| **Language** | GDScript |
| **Renderer** | **GL Compatibility**, so it runs on older GPUs and integrated graphics without Vulkan |
| **Graphics** | Custom spatial shaders (depth-aware water driven by a terrain height texture, procedural ice and rock), CPU particles, procedural meshes |
| **Audio** | All effects and music **synthesised at runtime** (`AudioStreamWAV`). Optional drop-in `.ogg/.wav/.mp3` replacements with random variants |
| **Models** | Buildings modelled in code. Optional **Blender 3.6/4.x** Python script exports `.glb` models that the game picks up automatically |
| **Localisation** | Godot `TranslationServer`, with English and Turkish |
| **Libraries / plugins** | None. No third-party dependencies |
| **Tooling** | Git, Blender, and the Claude AI assistant (Anthropic) as a coding and pair-programming aid |

## Controls

Defaults are shown below. **Every key marked ✱ can be rebound** in *Settings → Controls*.

| Input | Action |
|---|---|
| **Left click** | Place the selected building / select a tile |
| **Left click + drag** | **Box select**. With a building selected it fills the area, with *Demolish* it clears the area, with no tool it selects buildings |
| **Right click** / **Esc** | Cancel the tool or selection. Esc again opens the pause menu |
| **W A S D** ✱ / **Arrow keys** | Move the camera |
| **Middle mouse drag** | Pan the camera |
| **Q / E** ✱ | Rotate the view |
| **Mouse wheel** | Zoom |
| **Space** ✱ | Pause / resume |
| **,** and **.** ✱ | Slow down / speed up time |
| **T** ✱ | Toggle the flood forecast |
| **U** ✱ | Upgrade the selected building |
| **X** ✱ | Demolish tool |
| **1 – 0, -, =** | Select a building from the build bar |

Hover over anything for a short explanation. Tips appear as you play and can be turned off.

---

<div align="center">

Thank You

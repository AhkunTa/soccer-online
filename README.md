# Soccer Online

An enhanced arcade soccer game built with Godot 4.6, forked from [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course).

## ✨ New Features

### Jump System

- Press **PASS + SHOOT** simultaneously to jump
- Perform aerial shots: volley kicks, headers, bicycle kicks
- Jump shots have 1.5x power bonus

### Power Shot System (7 Types)

1. **NORMAL** - Enhanced speed shot
2. **HEIGHT_LIGHT** - Parabolic trajectory with precision
3. **RISING** - Slow rise then straight shot
4. **STRONG** - Ultra-fast flattened shot
5. **CURVE** - Dynamic arc around defenders
6. **INVISIBLE** - Ball vanishes mid-flight
7. **JUMP** - Bouncing rabbit-style shot

Requirements: 300+ power, 100+ units from goal, facing target

## 🎮 Core Features

- **9 Countries**: France, Argentina, Brazil, England, Germany, Italy, Spain, USA, Canada
- **Advanced AI**: Role-based behaviors (Goalie, Defender, Midfielder, Forward)
- **Realistic Physics**: Parabolic trajectories, friction, bounce mechanics
- **Player States**: Moving, Tackling, Jumping, Shooting, Passing, Header, Volley, Bicycle Kick, Chest Control
- **Temporary Boosts**: Stat multipliers with duration-based effects

## 🎯 Controls

| Action | Player 1  | Player 2  |
| ------ | --------- | --------- |
| Move   | WASD      | ⬆️⬇️⬅️➡️  |
| Shoot  | K         | ]         |
| Pass   | J         | [         |
| Jump   | J+K       | [+]       |
| Tackle | k(moving) | ](moving) |

**Tips**: Hold shoot to charge power • Jump + Shoot for aerial shots • Pass without ball to swap players

## 🛠️ Technical

- **Engine**: Godot 4.6 • **Language**: GDScript
- **Architecture**: State machine pattern
- **Physics**: Custom 2D with height simulation
- **Input**: Combo detection system
- **AI**: Role-based behaviors with steering

## 🚀 Quick Start

1. Install Godot 4.6+
2. Clone and open project
3. Press F5 to run

## 🔮 Planned

- Online multiplayer
- Tournament mode
- More power shots
- Player customization
- more animations

## 📝 Credits

Forked from [nicolasbize/soccer-course](https://github.com/nicolasbize/soccer-course) with major enhancements.

---

⚽ **Enjoy the game!**

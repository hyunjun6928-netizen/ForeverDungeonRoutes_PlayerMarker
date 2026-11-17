# Forever Dungeon Routes: 내 위치 표시 (Player Marker)

WoW: 포에버의 던전 지도 애드온 [Forever Dungeon Routes](https://www.curseforge.com/wow/addons/forever-dungeon-routes)(Checkov23 제작)에 얹는 **비공식 플러그인**입니다. 던전 안에서 내 위치를 그 지도에 금색 점으로 보여 줍니다.

## 필요한 것

- [Forever Dungeon Routes](https://www.curseforge.com/wow/addons/forever-dungeon-routes) ([GitHub](https://github.com/Checkov23/ForeverDungeonRoutes)). 이 플러그인만으로는 아무것도 하지 않습니다.

## 하는 일

게임은 던전 안에서 애드온에 좌표를 주지 않습니다. 그래서 Forever Dungeon Routes의 내 위치 점은 던전 안에서 나오지 않습니다. 이 플러그인은 게임이 알려주는 것만으로 점을 찍습니다.

- 게임이 방 이름을 알려주면 그 방 가운데
- 보스 전투가 시작되거나 끝나면 그 보스 자리
- 로딩 화면을 거쳐 들어오면 입구

방을 벗어나거나 한동안 걸으면 점이 흐려집니다(지나온 자리라는 뜻). 층이 바뀌면 지도가 따라갑니다.

## 한계

- 정확한 좌표가 아니라 **방 단위의 추정 위치**입니다.
- 방 이름이 없는 던전(그림자송곳니 성채, 스톰윈드 지하감옥, 가시덩굴 우리, 줄파락, 혈투의 전장 북쪽 등)에서는 입구와 보스 전투 때만 점이 움직입니다.
- 입구가 둘인 던전(마라우돈, 스트라솔름)은 어느 문으로 들어왔는지 알 수 없어, 방이나 보스 전투가 알려줄 때까지 점이 없습니다.

## 설치

1. Forever Dungeon Routes를 먼저 설치합니다.
2. [Releases](https://github.com/hyunjun6928-netizen/ForeverDungeonRoutes_PlayerMarker/releases/latest)에서 `ForeverDungeonRoutes_PlayerMarker-x.y.z.zip`을 받아 압축을 풉니다.
3. 나온 `ForeverDungeonRoutes_PlayerMarker` 폴더를 `World of Warcraft\_forever_\Interface\AddOns\` 안에 넣습니다.
4. 게임을 완전히 껐다 켭니다.

설정은 없습니다. 끄려면 애드온 목록에서 이 플러그인의 체크를 풀면 됩니다. Forever Dungeon Routes의 파일은 건드리지 않으며, 플러그인에서 오류가 나면 스스로 꺼지고 Forever Dungeon Routes는 원래대로 동작합니다.

---

# Forever Dungeon Routes: Player Marker

An **unofficial plugin** for [Forever Dungeon Routes](https://www.curseforge.com/wow/addons/forever-dungeon-routes) by Checkov23, the dungeon map addon for WoW: Forever. It shows where you are inside a dungeon as a golden dot on that addon's map.

## Requires

- [Forever Dungeon Routes](https://www.curseforge.com/wow/addons/forever-dungeon-routes) ([GitHub](https://github.com/Checkov23/ForeverDungeonRoutes)). The plugin does nothing on its own.

## What it does

Inside dungeons the game gives addons no coordinates, so the player marker of Forever Dungeon Routes never shows there. This plugin places it from what the game does tell:

- the room the game names: the middle of that room
- a boss fight starts or ends: that boss
- you came in through a loading screen: the entrance

Once you leave the named room or walk on for a while, the dot turns faint (the last place seen). When you change map levels, the map follows.

## Limits

- It is an **estimate, as exact as a room**, not a real position.
- In dungeons without named rooms (Shadowfang Keep, The Stockade, Razorfen Kraul, Zul'Farrak, Dire Maul North and others) the dot only moves at the entrance and at boss fights.
- In dungeons with two entrances (Maraudon, Stratholme) there is no dot until a room or a boss fight tells where you are.

## Install

1. Install Forever Dungeon Routes first.
2. Download `ForeverDungeonRoutes_PlayerMarker-x.y.z.zip` from [Releases](https://github.com/hyunjun6928-netizen/ForeverDungeonRoutes_PlayerMarker/releases/latest) and unpack it.
3. Put the folder `ForeverDungeonRoutes_PlayerMarker` into `World of Warcraft\_forever_\Interface\AddOns\`.
4. Quit the game and start it again.

There are no settings. To switch it off, untick the plugin in the addon list. It changes no file of Forever Dungeon Routes; if the plugin runs into an error it switches itself off and Forever Dungeon Routes carries on as usual.

## License

MIT (see LICENSE.txt). Not affiliated with Forever Dungeon Routes or its author.

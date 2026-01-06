Markdown

# 🌿 GeoQuest


**Gamifying Biodiversity.** GeoQuest is a collaborative, location-based mobile platform that turns nature exploration into an engaging game, encouraging users to discover, identify, and catalog plant species in their local environment.

## 💡 The Problem
In an increasingly digital world, "Plant Blindness" (the inability to see or notice the plants in one's own environment) is growing. Existing identification apps are solitary experiences. We wanted to build something that creates a **community** around conservation and makes going outside fun.

## 🚀 Key Features

### 🗺️ Interactive Exploration
* **Live Map:** View geotagged flora in your vicinity in real-time.
* **Discovery:** Click on pins to view species details, contributor history, and plant health status.

### 📸 Smart Identification & Validation
* **AI-Powered Scanning:** Instantly identify plants using the camera.
* **Anti-Cheat Engine:**
    * **Live Capture Only:** The app detects and prevents uploads from the gallery to ensure physical presence.
    * **Spam Prevention:** Users cannot scan the same plant (same geolocation radius) multiple times to farm XP.
    * **Duplicate Detection:** Prevents multiple users from spamming the exact same coordinate within a short timeframe.

### 🎮 Gamification
* **XP & Leveling:** Earn experience points for every unique discovery.
* **Streaks:** Daily activity tracking to build habits.
* **Leaderboards:** Compete with friends and local explorers.

### 🛡️ The Caretaker System
* **Adopt a Zone:** High-ranking users can become "Caretakers" of specific geographic zones.
* **Maintenance:** Caretakers are responsible for verifying data accuracy and "weeding out" incorrect tags in their zone.

---

## 🛠️ Tech Stack

| Component | Technology | Description |
| :--- | :--- | :--- |
| **Mobile App** | **Flutter** (or React Native) | Cross-platform UI for iOS and Android. |
| **Backend** | **Go (Golang)** / Node.js | High-performance API handling concurrent requests. |
| **Database** | **PostgreSQL** | Relational data storage. |
| **ORM** | **Prisma** | Schema management and type-safe database queries. |
| **Maps** | **Google Maps API** / Mapbox | Rendering the geospatial interface. |

---

## ⚙️ How We Handled "Anti-Cheat"
One of the biggest challenges was preventing users from "gaming" the system for points. We implemented a two-layer validation logic:

1.  **Geospatial Radius Check:**
    When a user submits a photo, the backend runs a PostGIS query to check if:
    * `User_ID` has submitted within `X` meters of `Current_Location` in the last `Y` hours.
    * If `True` -> Submission is rejected (Spam detected).

2.  **Metadata Verification:**
    We enforce camera-only inputs (no file picker) and validate image metadata to ensure the photo was taken at the moment of upload, preventing "internet photo" uploads.

---


Built with ❤️ at HackNITR 7.0

📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

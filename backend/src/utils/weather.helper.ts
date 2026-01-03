import axios from "axios";

// Helper: Fetch simplified weather context
export const getWeatherContext = async (lat: number, lon: number) => {
  try {
    const apiKey = process.env.OPENWEATHER_API_KEY;
    const url = `https://api.openweathermap.org/data/2.5/weather?lat=${lat}&lon=${lon}&units=metric&appid=${apiKey}`;
    
    const response = await axios.get(url);
    const data = response.data;

    return `Temperature: ${data.main.temp}°C, Condition: ${data.weather[0].description}, Humidity: ${data.main.humidity}%`;
  } catch (error) {
    console.error("Weather API Error:", error);
    return "Weather data unavailable (assume average conditions).";
  }
};
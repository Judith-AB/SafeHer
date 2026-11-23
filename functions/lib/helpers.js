const IST_OFFSET_MS = 330 * 60 * 1000;

const roundCoord = (x) => Math.round(x * 1000) / 1000; // ~111 m cell

// day: 0 = Sunday, as in Date.getDay()
function istParts(date) {
  const ist = new Date(date.getTime() + IST_OFFSET_MS);
  return { hour: ist.getUTCHours(), day: ist.getUTCDay() };
}

function truncateToIstHour(date) {
  const ms = date.getTime();
  return new Date(ms - ((ms + IST_OFFSET_MS) % 3600000));
}

function hourBand(hour) {
  if (hour >= 6 && hour < 12) return "06-12";
  if (hour >= 12 && hour < 18) return "12-18";
  if (hour >= 18) return "18-24";
  return "00-06";
}

const inIndia = (lat, lng) =>
  Number.isFinite(lat) && Number.isFinite(lng) && lat >= 6 && lat <= 37.5 && lng >= 68 && lng <= 97.5;

module.exports = { roundCoord, istParts, truncateToIstHour, hourBand, inIndia, IST_OFFSET_MS };

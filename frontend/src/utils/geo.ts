import { Coordinates } from '../features/daily-state/domain';

const GEO_BOUNDS = {
  north: 43.9,
  south: 36.0,
  west: -9.6,
  east: 3.5,
};

export function geoToCanvas(coordinates: Coordinates, width: number, height: number) {
  const xRatio = (coordinates.lng - GEO_BOUNDS.west) / (GEO_BOUNDS.east - GEO_BOUNDS.west);
  const yRatio = (GEO_BOUNDS.north - coordinates.lat) / (GEO_BOUNDS.north - GEO_BOUNDS.south);

  return {
    x: xRatio * width,
    y: yRatio * height,
  };
}

export function canvasToGeo(x: number, y: number, width: number, height: number): Coordinates {
  const safeWidth = width || 1;
  const safeHeight = height || 1;
  const lng = GEO_BOUNDS.west + (x / safeWidth) * (GEO_BOUNDS.east - GEO_BOUNDS.west);
  const lat = GEO_BOUNDS.north - (y / safeHeight) * (GEO_BOUNDS.north - GEO_BOUNDS.south);

  return {
    lat,
    lng,
  };
}

export function getSpainRegion() {
  return {
    latitude: 40.2,
    longitude: -3.7,
    latitudeDelta: 8.4,
    longitudeDelta: 11.5,
  };
}

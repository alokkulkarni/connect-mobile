// Where a payment happened. The sample data has no locations: merchant_places.json gives each sample merchant an
// illustrative place, or marks it as online (CONTRACT.md section 8).

export type PlaceEntry = { match: string; name?: string; area?: string; lat?: number; lng?: number; online?: boolean };

export type MerchantPlace =
  | { kind: 'place'; name: string; area: string; lat: number; lng: number }
  | { kind: 'online' }
  | { kind: 'unknown' };

export function lookupPlace(places: PlaceEntry[], merchant: string): MerchantPlace {
  const name = String(merchant || '').toUpperCase();
  // The longest match wins, so "UBER EATS" and "UBER TRIP" both find "UBER", and "BP" doesn't catch "BP..." early.
  const found = places
    .filter((p) => name.startsWith(p.match.toUpperCase()))
    .sort((a, b) => b.match.length - a.match.length)[0];
  if (!found) return { kind: 'unknown' };
  if (found.online) return { kind: 'online' };
  if (typeof found.lat === 'number' && typeof found.lng === 'number') {
    return { kind: 'place', name: found.name || merchant, area: found.area || '', lat: found.lat, lng: found.lng };
  }
  return { kind: 'unknown' };
}

export interface PlacesRepository {
  places(): PlaceEntry[];
}

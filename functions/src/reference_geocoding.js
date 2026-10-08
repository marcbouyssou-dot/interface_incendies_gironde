const IGN_SEARCH_URL = 'https://data.geopf.fr/geocodage/search/';
const MAX_RESULTS = 5;

export class ReferenceGeocodingError extends Error {
  constructor(code, message) {
    super(message);
    this.name = 'ReferenceGeocodingError';
    this.code = code;
  }
}

function validQuery(data) {
  if (!data || typeof data !== 'object' || Array.isArray(data)
    || Object.keys(data).length !== 1 || typeof data.query !== 'string') {
    throw new ReferenceGeocodingError('invalid-argument', 'Recherche invalide.');
  }
  const query = data.query.trim().replace(/\s+/g, ' ');
  if (query.length < 4 || query.length > 120 || /[\r\n<>@]/.test(query)
    || /(?:^|\D)\d{10,11}(?:\D|$)/.test(query)) {
    throw new ReferenceGeocodingError('invalid-argument', 'Saisissez un lieu ou une adresse, sans donnée personnelle.');
  }
  return query;
}

function validCoordinate(latitude, longitude) {
  return Number.isFinite(latitude) && latitude >= -90 && latitude <= 90
    && Number.isFinite(longitude) && longitude >= -180 && longitude <= 180;
}

function canonicalFeature(feature) {
  const coordinates = feature?.geometry?.coordinates;
  const properties = feature?.properties;
  if (feature?.geometry?.type !== 'Point' || !Array.isArray(coordinates)
    || coordinates.length !== 2 || !properties
    || typeof properties.label !== 'string'
    || properties.label.trim().length < 4
    || properties.label.length > 180
    || !validCoordinate(coordinates[1], coordinates[0])) return null;
  return {
    displayLabel: properties.label.trim(),
    latitude: coordinates[1],
    longitude: coordinates[0],
    provider: 'ign_geoplateforme',
    providerReference: typeof properties.id === 'string'
      && properties.id.length <= 120 ? properties.id : null,
    precision: typeof properties.type === 'string'
      && properties.type.length <= 40 ? properties.type : 'unknown',
    confidence: typeof properties.score === 'number'
      && Number.isFinite(properties.score)
      && properties.score >= 0 && properties.score <= 1
      ? properties.score : null,
  };
}

export async function searchIgnAddress(query, {
  fetchImpl = fetch,
  timeoutMs = 5000,
} = {}) {
  const url = new URL(IGN_SEARCH_URL);
  url.searchParams.set('q', query);
  url.searchParams.set('limit', String(MAX_RESULTS));
  url.searchParams.set('autocomplete', '0');
  try {
    const response = await fetchImpl(url, {
      method: 'GET',
      headers: {accept: 'application/json'},
      signal: AbortSignal.timeout(timeoutMs),
    });
    if (!response.ok) {
      throw new ReferenceGeocodingError('unavailable', 'Géocodage temporairement indisponible.');
    }
    const payload = await response.json();
    if (payload?.type !== 'FeatureCollection'
      || !Array.isArray(payload.features)) {
      throw new ReferenceGeocodingError('unavailable', 'Réponse de géocodage invalide.');
    }
    return payload.features.slice(0, MAX_RESULTS)
      .map(canonicalFeature).filter(Boolean);
  } catch (error) {
    if (error instanceof ReferenceGeocodingError) throw error;
    if (error?.name === 'TimeoutError' || error?.name === 'AbortError') {
      throw new ReferenceGeocodingError('deadline-exceeded', 'Le géocodage a expiré.');
    }
    throw new ReferenceGeocodingError('unavailable', 'Géocodage temporairement indisponible.');
  }
}

// Only the geographic query is forwarded to IGN. UID and profile data are
// checked locally and never included in the provider URL, headers or logs.
export async function searchProfessionalReferenceAddresses({
  db, callerUid, isAnonymous = false, data, searchProvider = searchIgnAddress,
}) {
  if (typeof callerUid !== 'string' || callerUid.length === 0 || isAnonymous) {
    throw new ReferenceGeocodingError('unauthenticated', 'Session professionnelle requise.');
  }
  const query = validQuery(data);
  const volunteer = await db.collection('volunteers').doc(callerUid).get();
  if (!volunteer.exists || volunteer.data()?.uid !== callerUid) {
    throw new ReferenceGeocodingError('permission-denied', 'Accès réservé au professionnel.');
  }
  return {results: await searchProvider(query)};
}

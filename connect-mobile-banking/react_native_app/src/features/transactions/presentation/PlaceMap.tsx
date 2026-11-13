// Where a payment happened: a map with a pin (the platform's map), or a card for online and direct debit payments.
import React from 'react';
import { Text, View } from 'react-native';
import MapView, { Marker } from 'react-native-maps';
import { useTheme } from '../../../core/theme/theme';
import type { MerchantPlace } from '../domain/places';

export function PlaceMap({ place }: { place: MerchantPlace }) {
  const { c, radius } = useTheme();
  if (place.kind !== 'place') {
    return (
      <View style={{ flexDirection: 'row', gap: 12, alignItems: 'center', backgroundColor: c.soft, borderRadius: radius - 4, padding: 14 }}>
        <Text style={{ fontSize: 26 }}>{place.kind === 'online' ? '🌐' : '🏦'}</Text>
        <View style={{ flex: 1 }}>
          <Text style={{ color: c.ink, fontWeight: '700' }}>{place.kind === 'online' ? 'Online payment' : 'No place to show'}</Text>
          <Text style={{ color: c.muted, fontSize: 13 }}>
            {place.kind === 'online' ? 'This was paid online or in an app, so there is no map.' : 'Direct debits, standing orders and transfers have no place.'}
          </Text>
        </View>
      </View>
    );
  }
  return (
    <View style={{ gap: 8 }}>
      <View style={{ height: 190, borderRadius: radius - 4, overflow: 'hidden', borderWidth: 1, borderColor: c.line }}>
        <MapView
          style={{ flex: 1 }}
          accessibilityLabel={`Map showing ${place.name}, ${place.area}`}
          initialRegion={{ latitude: place.lat, longitude: place.lng, latitudeDelta: 0.012, longitudeDelta: 0.012 }}
          scrollEnabled={false}
          zoomEnabled={false}
          pitchEnabled={false}
          rotateEnabled={false}
          toolbarEnabled={false}>
          <Marker coordinate={{ latitude: place.lat, longitude: place.lng }} title={place.name} description={place.area} pinColor={c.brand} />
        </MapView>
      </View>
      <Text style={{ color: c.ink, fontWeight: '600' }}>
        {place.name}, {place.area}
      </Text>
    </View>
  );
}

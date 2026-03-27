import { Alert, Platform } from 'react-native';

export function confirmAction(title: string, message: string) {
  if (Platform.OS === 'web' && typeof globalThis.confirm === 'function') {
    return Promise.resolve(globalThis.confirm(`${title}\n\n${message}`));
  }

  return new Promise<boolean>((resolve) => {
    Alert.alert(title, message, [
      { text: 'Cancelar', style: 'cancel', onPress: () => resolve(false) },
      { text: 'Sobrescribir', style: 'destructive', onPress: () => resolve(true) },
    ]);
  });
}

import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, Text, TextInput, View } from 'react-native';

import { WorkSite } from '../daily-state/domain';
import { colors } from '../../theme/tokens';
import { confirmAction } from '../../utils/confirm';
import { EdgeButton } from './LeftDrawer';

type WorkSitesDrawerProps = {
  workSites: WorkSite[];
  isOpen: boolean;
  hidden?: boolean;
  width: number;
  topOffset: number;
  onOpen: () => void;
  onClose: () => void;
  onAddWorkSite: (input: { name: string; city: string; lat: number; lng: number }) => void;
  onUpdateWorkSite: (
    workSiteId: string,
    input: { name: string; city: string; lat: number; lng: number },
  ) => void;
  onRemoveWorkSite: (workSiteId: string) => void;
};

type WorkDraft = {
  name: string;
  city: string;
  lat: string;
  lng: string;
};

const emptyDraft: WorkDraft = {
  name: '',
  city: '',
  lat: '40.2',
  lng: '-3.7',
};

export function WorkSitesDrawer({
  workSites,
  isOpen,
  hidden,
  width,
  topOffset,
  onOpen,
  onClose,
  onAddWorkSite,
  onUpdateWorkSite,
  onRemoveWorkSite,
}: WorkSitesDrawerProps) {
  const [search, setSearch] = useState('');
  const [drafts, setDrafts] = useState<Record<string, WorkDraft>>({});
  const [newDraft, setNewDraft] = useState<WorkDraft>(emptyDraft);

  const filtered = useMemo(() => {
    const needle = search.trim().toLowerCase();

    return workSites.filter((workSite) =>
      !needle
        ? true
        : `${workSite.name} ${workSite.city}`.toLowerCase().includes(needle),
    );
  }, [search, workSites]);

  const handleDelete = async (workSiteId: string, name: string) => {
    const confirmed = await confirmAction(
      'Eliminar obra',
      `Se eliminara ${name} y se desasignara de los dias guardados.`,
    );

    if (confirmed) {
      onRemoveWorkSite(workSiteId);
    }
  };

  const handleCreate = () => {
    const name = newDraft.name.trim();
    const city = newDraft.city.trim();
    const lat = Number(newDraft.lat);
    const lng = Number(newDraft.lng);

    if (!name || !city || Number.isNaN(lat) || Number.isNaN(lng)) {
      return;
    }

    onAddWorkSite({ name, city, lat, lng });
    setNewDraft(emptyDraft);
  };

  return (
    <>
      {isOpen ? (
        <View style={[styles.drawer, { width, top: topOffset, right: 16 }]}>
          <View style={styles.drawerHeader}>
            <Text style={styles.drawerTitle}>Obras</Text>
            <Pressable onPress={onClose} style={({ pressed }) => [styles.iconButton, pressed && styles.pressed]}>
              <Text style={styles.iconButtonText}>×</Text>
            </Pressable>
          </View>

          <ScrollView contentContainerStyle={styles.content}>
            <TextInput
              value={search}
              onChangeText={setSearch}
              placeholder="Buscar obras"
              placeholderTextColor={colors.textMuted}
              style={styles.searchInput}
            />

            {filtered.map((workSite) => {
              const draft = drafts[workSite.id] ?? {
                name: workSite.name,
                city: workSite.city,
                lat: String(workSite.lat),
                lng: String(workSite.lng),
              };

              return (
                <View key={workSite.id} style={styles.rowCard}>
                  <TextInput
                    value={draft.name}
                    onChangeText={(value) =>
                      setDrafts((current) => ({
                        ...current,
                        [workSite.id]: { ...draft, name: value },
                      }))
                    }
                    placeholder="Nombre"
                    placeholderTextColor={colors.textMuted}
                    style={styles.input}
                  />

                  <TextInput
                    value={draft.city}
                    onChangeText={(value) =>
                      setDrafts((current) => ({
                        ...current,
                        [workSite.id]: { ...draft, city: value },
                      }))
                    }
                    placeholder="Ciudad"
                    placeholderTextColor={colors.textMuted}
                    style={styles.input}
                  />

                  <View style={styles.coordinatesRow}>
                    <TextInput
                      value={draft.lat}
                      onChangeText={(value) =>
                        setDrafts((current) => ({
                          ...current,
                          [workSite.id]: { ...draft, lat: value },
                        }))
                      }
                      placeholder="Lat"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.input, styles.coordinateInput]}
                    />
                    <TextInput
                      value={draft.lng}
                      onChangeText={(value) =>
                        setDrafts((current) => ({
                          ...current,
                          [workSite.id]: { ...draft, lng: value },
                        }))
                      }
                      placeholder="Lng"
                      placeholderTextColor={colors.textMuted}
                      style={[styles.input, styles.coordinateInput]}
                    />
                  </View>

                  <View style={styles.rowActions}>
                    <IconAction
                      label="✎"
                      onPress={() => {
                        const lat = Number(draft.lat);
                        const lng = Number(draft.lng);

                        if (!draft.name.trim() || !draft.city.trim() || Number.isNaN(lat) || Number.isNaN(lng)) {
                          return;
                        }

                        onUpdateWorkSite(workSite.id, {
                          name: draft.name.trim(),
                          city: draft.city.trim(),
                          lat,
                          lng,
                        });
                      }}
                    />
                    <IconAction label="📁" onPress={() => undefined} />
                    <IconAction label="🗑" onPress={() => handleDelete(workSite.id, workSite.name)} />
                  </View>
                </View>
              );
            })}

            <View style={styles.createCard}>
              <Text style={styles.createTitle}>Nueva obra</Text>
              <TextInput
                value={newDraft.name}
                onChangeText={(value) => setNewDraft((current) => ({ ...current, name: value }))}
                placeholder="Nombre"
                placeholderTextColor={colors.textMuted}
                style={styles.input}
              />
              <TextInput
                value={newDraft.city}
                onChangeText={(value) => setNewDraft((current) => ({ ...current, city: value }))}
                placeholder="Ciudad"
                placeholderTextColor={colors.textMuted}
                style={styles.input}
              />
              <View style={styles.coordinatesRow}>
                <TextInput
                  value={newDraft.lat}
                  onChangeText={(value) => setNewDraft((current) => ({ ...current, lat: value }))}
                  placeholder="Lat"
                  placeholderTextColor={colors.textMuted}
                  style={[styles.input, styles.coordinateInput]}
                />
                <TextInput
                  value={newDraft.lng}
                  onChangeText={(value) => setNewDraft((current) => ({ ...current, lng: value }))}
                  placeholder="Lng"
                  placeholderTextColor={colors.textMuted}
                  style={[styles.input, styles.coordinateInput]}
                />
              </View>
              <View style={styles.createActionWrap}>
                <IconAction label="＋" onPress={handleCreate} />
              </View>
            </View>
          </ScrollView>
        </View>
      ) : hidden ? null : (
        <EdgeButton side="right" label="Obras" onPress={onOpen} topOffset={topOffset + 122} />
      )}
    </>
  );
}

function IconAction({ label, onPress }: { label: string; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={({ pressed }) => [styles.actionButton, pressed && styles.pressed]}>
      <Text style={styles.actionText}>{label}</Text>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  drawer: {
    position: 'absolute',
    bottom: 16,
    borderRadius: 26,
    backgroundColor: 'rgba(9, 20, 30, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.18)',
    overflow: 'hidden',
  },
  drawerHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingHorizontal: 18,
    paddingTop: 16,
    paddingBottom: 10,
  },
  drawerTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
  },
  iconButton: {
    width: 32,
    height: 32,
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(255, 255, 255, 0.08)',
  },
  iconButtonText: {
    color: colors.text,
    fontSize: 22,
    lineHeight: 22,
  },
  content: {
    paddingHorizontal: 18,
    paddingBottom: 18,
    gap: 12,
  },
  searchInput: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 14,
    color: colors.text,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.16)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
  },
  rowCard: {
    padding: 12,
    borderRadius: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    gap: 10,
  },
  input: {
    paddingHorizontal: 12,
    paddingVertical: 10,
    borderRadius: 14,
    color: colors.text,
    borderWidth: 1,
    borderColor: 'rgba(151, 181, 200, 0.16)',
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
  },
  coordinatesRow: {
    flexDirection: 'row',
    gap: 10,
  },
  coordinateInput: {
    flex: 1,
  },
  rowActions: {
    flexDirection: 'row',
    justifyContent: 'flex-end',
    gap: 8,
  },
  actionButton: {
    width: 36,
    height: 36,
    borderRadius: 12,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'rgba(16, 34, 50, 0.92)',
    borderWidth: 1,
    borderColor: 'rgba(56, 189, 248, 0.12)',
  },
  actionText: {
    color: colors.text,
    fontSize: 15,
    fontWeight: '700',
  },
  createCard: {
    padding: 14,
    borderRadius: 18,
    backgroundColor: 'rgba(255, 255, 255, 0.04)',
    gap: 10,
  },
  createTitle: {
    color: colors.text,
    fontWeight: '700',
  },
  createActionWrap: {
    alignItems: 'flex-end',
  },
  pressed: {
    opacity: 0.82,
  },
});

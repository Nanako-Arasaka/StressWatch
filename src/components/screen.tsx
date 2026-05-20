import { PropsWithChildren } from "react";
import { ScrollView, Text, View } from "react-native";

import { colors } from "@/theme/colors";

export function Screen({
  title,
  subtitle,
  children
}: PropsWithChildren<{ title: string; subtitle?: string }>) {
  return (
    <ScrollView
      contentInsetAdjustmentBehavior="automatic"
      style={{ flex: 1, backgroundColor: colors.background }}
      contentContainerStyle={{ padding: 20, paddingBottom: 120, gap: 16 }}
    >
      <View style={{ gap: 6 }}>
        <Text
          selectable
          style={{ color: colors.text, fontSize: 34, fontWeight: "800", letterSpacing: 0 }}
        >
          {title}
        </Text>
        {subtitle ? (
          <Text selectable style={{ color: colors.textMuted, fontSize: 15, lineHeight: 21 }}>
            {subtitle}
          </Text>
        ) : null}
      </View>
      {children}
    </ScrollView>
  );
}

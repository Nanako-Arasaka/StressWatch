import { PropsWithChildren, useEffect, useRef } from "react";
import { Animated, ViewStyle } from "react-native";

export function AnimatedCard({
  children,
  delay = 0,
  style
}: PropsWithChildren<{ delay?: number; style?: ViewStyle }>) {
  const opacity = useRef(new Animated.Value(0)).current;
  const translateY = useRef(new Animated.Value(14)).current;

  useEffect(() => {
    Animated.sequence([
      Animated.delay(delay),
      Animated.parallel([
        Animated.timing(opacity, {
          toValue: 1,
          duration: 360,
          useNativeDriver: true
        }),
        Animated.spring(translateY, {
          toValue: 0,
          damping: 18,
          stiffness: 140,
          mass: 0.8,
          useNativeDriver: true
        })
      ])
    ]).start();
  }, [delay, opacity, translateY]);

  return (
    <Animated.View
      style={[
        style,
        {
          opacity,
          transform: [{ translateY }]
        }
      ]}
    >
      {children}
    </Animated.View>
  );
}

declare module "@kingstinct/react-native-healthkit" {
  export function isHealthDataAvailable(): Promise<boolean>;

  export function requestAuthorization(options: {
    toRead: string[];
    toWrite?: string[];
  }): Promise<void>;

  export function queryQuantitySamples(
    identifier: string,
    options?: Record<string, unknown>
  ): Promise<
    Array<{
      uuid?: string;
      quantity?: number;
      unit?: string;
      startDate?: Date | string;
      endDate?: Date | string;
    }>
  >;

  export function queryCategorySamples(
    identifier: string,
    options?: Record<string, unknown>
  ): Promise<
    Array<{
      uuid?: string;
      value?: number;
      startDate?: Date | string;
      endDate?: Date | string;
    }>
  >;
}

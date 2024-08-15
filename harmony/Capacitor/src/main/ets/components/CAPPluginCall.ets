export type CAPPlugin = ESObject
export type CAPPluginModule = CAPPlugin

export interface CAPPluginCallData {
  callbackId: string;
  pluginId: string;
  methodName: string;
  options: Object;
}

export interface CAPPluginCall {
  data: CAPPluginCallData;
  callback: (result: CAPPluginCallResult) => void;
}

interface CAPPluginError {
  message: string;
}

export interface CAPPluginCallResult {
  callbackId?: string;
  pluginId?: string;
  methodName?: string;
  success: boolean;
  data?: Object | null;
  save?: boolean
  error?: CAPPluginError;
}

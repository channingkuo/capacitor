import { webview } from '@kit.ArkWeb';
import { JSON } from '@kit.ArkTS';
import { convertCamelToKebab } from './utils/index'
import { CAPPluginCall, CAPPluginCallResult, CAPPlugin, CAPPluginModule } from './CAPPluginCall';
import { BusinessError } from '@kit.BasicServicesKit';

export class CapacitorBridge {
  private webViewController: webview.WebviewController = new webview.WebviewController();

  constructor(webViewController: webview.WebviewController) {
    this.webViewController = webViewController;
  }

  public postMessage(pluginCall: Object): void {
    console.log(`⚡️ CapacitorBridge: ${JSON.stringify(pluginCall)}`);

    const call = pluginCall as CAPPluginCall;
    const callbackId = call.data.callbackId;
    const moduleName = convertCamelToKebab(call.data.pluginId);
    const pluginName = call.data.pluginId + 'Plugin';
    const methodName = call.data.methodName;
    try {
      import(moduleName).then((pluginModule: CAPPluginModule) => {
        let plugin: CAPPlugin = new pluginModule[pluginName]();

        let callData: CAPPluginCall = {
          data: call.data,
          callback: (result: CAPPluginCallResult) => {
            result.callbackId = callbackId;
            result.pluginId = call.data.pluginId;
            result.methodName = methodName;
            const resultStringify = JSON.stringify(result);
            this.webViewController.runJavaScript(`Capacitor.fromNative(${resultStringify})`);
          }
        };
        plugin[methodName](callData)
      }).catch((error: BusinessError) => {
        console.error(`⚡️ CapacitorBridge excute plugin error: ${error.message}`);
        console.error(`⚡️ CapacitorBridge excute plugin error stack:  ${error.stack}`);

        const callResult: CAPPluginCallResult = {
          callbackId: callbackId,
          pluginId: moduleName,
          success: false,
          error: { message: `⚡️ ${pluginName} invoker ${methodName} error: ${error.message}` }
        }
        const resultStringify = JSON.stringify(callResult);
        this.webViewController.runJavaScript(`harmonyBridge.onmessage(${resultStringify})`);
      });
    } catch (e) {
      console.error(`⚡️ CapacitorBridge resolve plugin error: ${JSON.stringify(e)}`);

      const callResult: CAPPluginCallResult = {
        callbackId: callbackId,
        pluginId: moduleName,
        success: false,
        error: { message: `⚡️ implementation unavailable for ${pluginName}` }
      }
      const resultStringify = JSON.stringify(callResult);
      this.webViewController.runJavaScript(`harmonyBridge.onmessage(${resultStringify})`);
    }
  }
}

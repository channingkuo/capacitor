import { ArrayList, JSON } from '@kit.ArkTS';
import { webview } from '@kit.ArkWeb';
import { BusinessError } from '@kit.BasicServicesKit';
import common from '@ohos.app.ability.common';
import { CAPPlugin, CAPPluginModule } from './CAPPluginCall'
import BuildProfile from '../../../../BuildProfile';

type Context = common.UIAbilityContext;

export class JSExport {
  private static RETURN_CALLBACK = 'callback';
  private static RETURN_NONE = 'none';
  private static RETURN_PROMISE = 'promise';
  private static CATCHALL_OPTIONS_PARAM = '_options';
  private static CALLBACK_PARAM = '_callback';

  static async getGlobalJS(): Promise<string> {
    return 'window.harmony=true;\nwindow.Capacitor = { DEBUG: ' + BuildProfile.DEBUG + ', isLoggingEnabled: ' + BuildProfile.DEBUG + ', Plugins: {} };';
  }

  static async getBridgeJS(context: Context): Promise<string> {
    return await JSExport.loadConfigContent('native-bridge.js', context);
  }

  static async getPluginJS(context: Context): Promise<string> {
    const pluginConfig = await JSExport.loadConfigContent('config/capacitor.plugins.json', context);
    const pluginsJSON = JSON.parse(pluginConfig) as ArrayList<Record<string, string>>;

    let lines = new ArrayList<string>();
    let pluginArray = new ArrayList<Record<string, Object>>();

    lines.add("// Begin: Capacitor Plugin JS");

    for (let i = 0; i < pluginsJSON.length; ++i) {
      const plugin: Record<string, string> = pluginsJSON[i];

      const pluginHandle = await JSExport.getPluginHandle(plugin);
      if (!pluginHandle) {
        continue;
      }

      lines.add(
        "(function(w) {\n" +
          "var a = (w.Capacitor = w.Capacitor || {});\n" +
          "var p = (a.Plugins = a.Plugins || {});\n" +
          "var t = (p['" +
        pluginHandle['jsName'] +
          "'] = {});\n" +
          "t.addListener = function(eventName, callback) {\n" +
          "  return w.Capacitor.addListener('" +
        pluginHandle['jsName'] +
          "', eventName, callback);\n" +
          "}"
      );

      const methods = pluginHandle['pluginMethods'] as [Record<string, string>]
      for (let m = 0; m < methods.length; ++m) {
        const method = methods[m];
        if (method['name'] === "addListener" || method['name'] === "removeListener") {
          // Don't export add/remove listener, we do that automatically above as they are "special snowflakes"
          continue;
        }
        lines.add(JSExport.generateMethodJS(pluginHandle, method));
      }

      lines.add("})(window);\n");
      pluginArray.add(JSExport.createPluginHeader(pluginHandle));
    }

    return lines.convertToArray().join('\n') +
      "\n" +
      "window.Capacitor.PluginHeaders = " +
    JSON.stringify(pluginArray.convertToArray()) + ";";
  }

  static exportCordovaJS(context: Context, webViewController: webview.WebviewController): void {

  }

  static exportCordovaPluginsJS(context: Context, webViewController: webview.WebviewController): void {

  }

  static injectFilesForFolder(folderPath: string, context: common.UIAbilityContext,
    webViewController: webview.WebviewController): void {
    // try {
    //   context.resourceManager.getRawFileContent(filePath, (error: BusinessError, array: Uint8Array) => {
    //     if (error != null) {
    //       console.error(`⚡️ getRawFd: ${filePath} failed, error code: ${error.code}, message: ${error.message}.`);
    //     } else {
    //       const data = Array.from(array, (byte) => String.fromCharCode(byte)).join('')
    //       // console.info(`⚡️ Raw file: ${filePath} content: ` + data);
    //       webViewController.runJavaScript(data).then((res: string) => {
    //         console.info(`⚡️ runJavaScript result: ${res}`);
    //       }).catch((err: BusinessError) => {
    //         console.error(`⚡️ runJavaScript failed, error code: ${err.code}, message: ${err.message}.`)
    //       })
    //     }
    //   });
    // } catch (e) {
    //   console.error(`⚡️ injectFile: ${filePath} error: ${e.message}`)
    // }
  }


  static injectFile(filePath: string, context: Context, webViewController: webview.WebviewController): void {
    try {
      context.resourceManager.getRawFileContent(filePath, (error: BusinessError, array: Uint8Array) => {
        if (error != null) {
          console.error(`⚡️ getRawFd: ${filePath} failed, error code: ${error.code}, message: ${error.message}.`);
        } else {
          const data = Array.from(array, (byte) => String.fromCharCode(byte)).join('')
          // console.info(`⚡️ Raw file: ${filePath} content: ` + data);
          webViewController.runJavaScript(data).then((res: string) => {
            console.info(`⚡️ runJavaScript result: ${res}`);
          }).catch((err: BusinessError) => {
            console.error(`⚡️ runJavaScript failed, error code: ${err.code}, message: ${err.message}.`)
          })
        }
      });
    } catch (e) {
      console.error(`⚡️ injectFile: ${filePath} error: ${e.message}`)
    }
  }

  static async loadConfigContent(filePath: string, context: Context): Promise<string> {
    try {
      const data = await context.resourceManager.getRawFileContent(filePath);
      return Array.from(data, (byte) => String.fromCharCode(byte)).join('');
    } catch (e) {
      console.error(`⚡️ read  ${filePath} failed, error message: ${e.message}`);
      throw new Error(`⚡️ read  ${filePath} failed, error message: ${e.message}`);
    }
  }

  static async getPluginHandle(plugin: Record<string, string>): Promise<Record<string, Object> | null> {
    const moduleName = JSExport.getPluginModuleName(plugin);
    const pluginName = JSExport.getPluginName(plugin);
    try {
      const pluginModule: CAPPluginModule = await import(moduleName);
      let pluginInstance: CAPPlugin = new pluginModule[pluginName]();
      const pluginMethods = pluginInstance.pluginMethods as [Record<string, string>];
      const identifier = pluginInstance.pluginInstance as string
      const jsName = pluginInstance.jsName as string
      return { 'pluginMethods': pluginMethods, 'identifier': identifier, 'jsName': jsName };
    } catch (e) {
      console.error(`⚡️ don't find the plugin: ${pluginName}, error: ${e}`)
    }
    return null;
  }

  static createPluginHeader(pluginHandle: Record<string, Object>): Record<string, Object> {
    return { 'name': pluginHandle['jsName'], 'methods': pluginHandle['pluginMethods'] }
  }

  static generateMethodJS(pluginHandle: Record<string, Object>, method: Record<string, string>): string {
    let lines = new ArrayList<string>();

    let args = new ArrayList<string>();
    // Add the catch all param that will take a full javascript object to pass to the plugin
    args.add(JSExport.CATCHALL_OPTIONS_PARAM);

    let returnType = method['returnType'];
    if (returnType === JSExport.RETURN_CALLBACK) {
      args.add(JSExport.CALLBACK_PARAM);
    }

    // Create the method function declaration
    lines.add("t['" + method['name'] + "'] = function(" + args.convertToArray().join(', ') + ") {");

    switch (returnType) {
      case JSExport.RETURN_NONE:
        lines.add(
          "return w.Capacitor.nativeCallback('" +
          pluginHandle['jsName'] +
            "', '" +
          method['name'] +
            "', " +
          JSExport.CATCHALL_OPTIONS_PARAM +
            ")"
        );
        break;
      case JSExport.RETURN_PROMISE:
        lines.add(
          "return w.Capacitor.nativePromise('" + pluginHandle['jsName'] + "', '" + method['name'] + "', " +
          JSExport.CATCHALL_OPTIONS_PARAM + ")"
        );
        break;
      case JSExport.RETURN_CALLBACK:
        lines.add(
          "return w.Capacitor.nativeCallback('" +
          pluginHandle['jsName'] +
            "', '" +
          method['name'] +
            "', " +
          JSExport.CATCHALL_OPTIONS_PARAM +
            ", " +
          JSExport.CALLBACK_PARAM +
            ")"
        );
        break;
      default:
    // TODO: Do something here?
    }

    lines.add("}");

    return lines.convertToArray().join("\n");
  }

  static getPluginModuleName(plugin: Record<string, string>): string {
    const pluginSplit = plugin['module'];
    return pluginSplit.toLowerCase();
  }

  static getPluginName(plugin: Record<string, string>): string {
    const pluginName = plugin['plugin'];
    return pluginName.endsWith('Plugin') ? pluginName : `${pluginName}Plugin`;
  }
}
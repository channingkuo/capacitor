import { webview } from '@kit.ArkWeb';
import { uri } from '@kit.ArkTS';
import common from '@ohos.app.ability.common';

@Component
export struct Capacitor {
  scheme: string = 'http';
  host: string = 'localhost';
  @State webViewController: webview.WebviewController = new webview.WebviewController();
  @State context: common.UIAbilityContext = getContext() as common.UIAbilityContext;

  build() {
    Web({ src: this.host, controller: this.webViewController })
      // http and https mixed use
      .mixedMode(MixedMode.All)
        // web localstorage accessible
      .domStorageAccess(true)
        // web location accessible
      .geolocationAccess(true)
      .darkMode(WebDarkMode.Auto)
        // web console
      .onConsole((event: OnConsoleEvent) => {
        console.log('⚡️ web console: ' + event.message.getMessage(),
          event.message.getSourceId(),
          event.message.getLineNumber()
        );
        return true;
      })
        // web resource load error
      .onErrorReceive((event: OnErrorReceiveEvent) => {
        console.log('⚡️ web resource load error: ' + event.request.getRequestUrl());
      })
        // intercept
      .onInterceptRequest((event: OnInterceptRequestEvent) => {
        return this.onInterceptRequest(event.request);
      })
        // intercept prompt to show native prompt
      .onPrompt((event: OnPromptEvent) => {
        // TODO show native prompt
        return false;
      })
        // intercept confirm to show native confirm
      .onConfirm((event: OnConfirmEvent) => {
        // TODO show native confirm
        return false;
      })
        // intercept alert to show native alert
      .onAlert((event: OnAlertEvent) => {
        // TODO show native alert
        return false;
      })
        // inject native method into web
        // .javaScriptProxy()
        // web start loading
      .onPageBegin((event: OnPageBeginEvent) => {
        // JsExport.initialJsExport(this.context, this.webViewController);
      })
        // web end loading
      .onPageEnd((event: OnPageEndEvent) => {
        // setTimeout(() => {
        //   this.webViewController.startCamera();
        // }, 5000)
      })
      .width('100%')
      .height('100%')
  }

  onInterceptRequest(request: WebResourceRequest): WebResourceResponse | null {
    console.log('⚡️ intercept request: ' + request.getRequestUrl());

    const requestUrl = request.getRequestUrl();
    const requestUri = new uri.URI(requestUrl);
    const filePath = requestUri.path;

    if (requestUrl.startsWith(this.buildServerUrl())) {
      const reserverFilePath = filePath === '/' ? 'www/index.html' : 'www' + filePath;
      console.log('⚡️ back proxy request to: resource://rawfile/' + reserverFilePath);

      const webResourceResponse = new WebResourceResponse();
      webResourceResponse.setResponseData($rawfile(reserverFilePath));
      webResourceResponse.setResponseMimeType(this.checkMimeType(reserverFilePath));
      webResourceResponse.setResponseEncoding('UTF-8');
      webResourceResponse.setResponseCode(200);
      return webResourceResponse;
    }
    return null;
  }

  buildServerUrl(): string {
    return this.scheme + '://' + this.host
  }

  checkMimeType(filePath: string): string {
    let mimeType = 'text/html';
    if (filePath.endsWith('.html')) {
      mimeType = 'text/html';
    } else if (filePath.endsWith('.css')) {
      mimeType = 'text/css';
    } else if (filePath.endsWith('.js')) {
      mimeType = 'application/javascript';
    } else if (filePath.endsWith('.svg')) {
      mimeType = 'image/svg+xml';
    } else if (filePath.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (filePath.endsWith('.jpg')) {
      mimeType = 'image/jpeg';
    } else if (filePath.endsWith('.map')) {
      mimeType = 'application/js';
    } else if (filePath.endsWith('.json')) {
      mimeType = 'application/json';
    } else if (filePath.endsWith('.png')) {
      mimeType = 'image/png';
    } else if (filePath.endsWith('.bin')) {
      mimeType = 'application/octet-stream';
    } else if (filePath.endsWith('.wasm')) {
      mimeType = 'application/wasm';
    } else {
      mimeType = 'text/html';
    }
    return mimeType;
  }
}

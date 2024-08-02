import { webview } from '@kit.ArkWeb';
import { uri } from '@kit.ArkTS';

@Entry
@Component
struct WebComponent {
  scheme: string = 'http';
  host: string = 'localhost';
  controller: webview.WebviewController = new webview.WebviewController();

  build() {
    Column() {
      Web({ src: this.host, controller: this.controller })
        .mixedMode(MixedMode.All)
        .domStorageAccess(true)
        .onConsole((event: OnConsoleEvent) => {
          console.log('onConsole: ' + event.message.getMessage(),
            event.message.getSourceId(),
            event.message.getLineNumber()
          );
          return true;
        })
        .onErrorReceive((event: OnErrorReceiveEvent) => {
          console.log('onErrorReceive: ' + event.request.getRequestUrl());
        })
        .onInterceptRequest((event: OnInterceptRequestEvent) => {
          return this.onInterceptRequest(event.request);
        })
    }
  }

  onInterceptRequest(request: WebResourceRequest): WebResourceResponse | null {
    console.log('onInterceptRequest: ' + request.getRequestUrl());

    const requestUrl = request.getRequestUrl();
    const requestUri = new uri.URI(requestUrl);
    const filePath = requestUri.path;

    if (requestUrl.startsWith(this.buildServerUrl())) {
      console.log('request filePath: ' + filePath);

      let reserverFilePath = '';
      if (filePath === '/') {
        reserverFilePath = 'www/index.html';
      } else {
        reserverFilePath = 'www' + filePath;
      }
      const webResourceResponse = new WebResourceResponse();
      webResourceResponse.setResponseData($rawfile(reserverFilePath));
      webResourceResponse.setResponseMimeType(this.checkMimeType(reserverFilePath));
      webResourceResponse.setResponseEncoding("UTF-8");
      webResourceResponse.setResponseCode(200);
      return webResourceResponse;
    }
    return null;
  }

  buildServerUrl() {
    return this.scheme + '://' + this.host
  }

  checkMimeType(filePath: string) {
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

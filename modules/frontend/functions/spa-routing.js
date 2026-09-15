function handler(event) {
  var request = event.request;
  var uri = request.uri;

  // 拡張子付き（静的アセット）はそのままS3へ。それ以外はSPAのクライアントサイドルートとして
  // index.htmlへ書き換える（S3のOACはListBucket権限が無く、無いパスは403を返すため、
  // custom_error_response(403→200)によるエラーコード変換に頼らずリクエスト時点で解決する）
  if (!uri.includes('.')) {
    request.uri = '/index.html';
  }

  return request;
}

package com.example.graphhopperapp.api;


import android.util.Log;


import androidx.annotation.NonNull;


import com.example.graphhopperapp.AppSettings;
import com.example.graphhopperapp.model.GeoPoint;
import com.example.graphhopperapp.model.RouteResult;


import org.json.JSONArray;
import org.json.JSONObject;


import java.io.IOException;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.security.cert.X509Certificate;
import java.util.List;
import java.util.concurrent.TimeUnit;


import javax.net.ssl.SSLContext;
import javax.net.ssl.TrustManager;
import javax.net.ssl.X509TrustManager;


import okhttp3.HttpUrl;
import okhttp3.OkHttpClient;
import okhttp3.Request;
import okhttp3.Response;
import okhttp3.ResponseBody;


/**
* Thin wrapper around the GraphHopper Directions API (Geocoding + Routing).
*
* Endpoints used (relative to the configured base URL, default
* https://graphhopper.com/api/1):
*   GET /geocode?q=...&limit=1&locale=..&key=..
*   GET /route?point=lat,lon&point=lat,lon&profile=..&points_encoded=true&key=..
*
* Network calls block, so callers must invoke these off the main thread.
*/
public class GraphHopperClient {


   private final OkHttpClient http;
   private final AppSettings settings;


   public GraphHopperClient(AppSettings settings) {
       this.settings = settings;
       this.http = getUnsafeOkHttpClient();
   }


   private static OkHttpClient getUnsafeOkHttpClient() {
       try {
           // Create a trust manager that does not validate certificate chains
           final TrustManager[] trustAllCerts = new TrustManager[]{
                   new X509TrustManager() {
                       @Override
                       public void checkClientTrusted(X509Certificate[] chain, String authType) {}
                       @Override
                       public void checkServerTrusted(X509Certificate[] chain, String authType) {}
                       @Override
                       public X509Certificate[] getAcceptedIssuers() {
                           return new X509Certificate[]{};
                       }
                   }
           };


           // Install the all-trusting trust manager
           final SSLContext sslContext = SSLContext.getInstance("SSL");
           sslContext.init(null, trustAllCerts, new SecureRandom());


           return new OkHttpClient.Builder()
                   .sslSocketFactory(sslContext.getSocketFactory(), (X509TrustManager) trustAllCerts[0])
                   .hostnameVerifier((hostname, session) -> true)
                   .connectTimeout(15, TimeUnit.SECONDS)
                   .readTimeout(20, TimeUnit.SECONDS)
                   .build();
       } catch (Exception e) {
           throw new RuntimeException(e);
       }
   }


   /** Raised for any API/transport error so the UI can show a message. */
   public static class ApiException extends Exception {
       public ApiException(String message) {
           super(message);
       }
   }


   /**
    * Forward-geocode a free-text query into a single best {@link GeoPoint}.
    * Returns null if the API returns no hits.
    */
   public GeoPoint geocode(@NonNull String query) throws ApiException {
       HttpUrl base = HttpUrl.parse(settings.getBaseUrl());
       if (base == null) {
           throw new ApiException("Invalid API base URL");
       }
       HttpUrl url = base.newBuilder()
               .addPathSegment("geocode")
               .addQueryParameter("q", query)
               .addQueryParameter("limit", "1")
               .addQueryParameter("locale", settings.getLocale())
               .addQueryParameter("key", settings.getApiKey())
               .build();


       String body = executeGet(url.toString());
       try {
           JSONObject root = new JSONObject(body);
           JSONArray hits = root.optJSONArray("hits");
           if (hits == null || hits.length() == 0) {
               return null;
           }
           JSONObject first = hits.getJSONObject(0);
           JSONObject point = first.getJSONObject("point");
           double lat = point.getDouble("lat");
           double lon = point.getDouble("lng");
           String name = first.optString("name", query);
           return new GeoPoint(lat, lon, name);
       } catch (Exception e) {
           throw new ApiException("Could not parse geocoding response: " + e.getMessage());
       }
   }


   /**
    * Request a route between two points using the configured profile.
    */
   public RouteResult route(@NonNull GeoPoint from, @NonNull GeoPoint to) throws ApiException {
       HttpUrl base = HttpUrl.parse(settings.getBaseUrl());
       if (base == null) {
           throw new ApiException("Invalid API base URL");
       }
       HttpUrl url = base.newBuilder()
               .addPathSegment("route")
               .addQueryParameter("point", from.lat + "," + from.lon)
               .addQueryParameter("point", to.lat + "," + to.lon)
               .addQueryParameter("profile", settings.getProfile())
               .addQueryParameter("locale", settings.getLocale())
               .addQueryParameter("points_encoded", "true")
               .addQueryParameter("instructions", "false")
               .addQueryParameter("calc_points", "true")
               .addQueryParameter("key", settings.getApiKey())
               .build();


       String body = executeGet(url.toString());
       try {
           JSONObject root = new JSONObject(body);
           JSONArray paths = root.optJSONArray("paths");
           if (paths == null || paths.length() == 0) {
               return null;
           }
           JSONObject path = paths.getJSONObject(0);
           double distance = path.optDouble("distance", 0);
           long time = path.optLong("time", 0);
           String encoded = path.optString("points", "");
           List<GeoPoint> points = PolylineDecoder.decode(encoded);
           if (points.isEmpty()) {
               return null;
           }
           return new RouteResult(points, distance, time);
       } catch (Exception e) {
           throw new ApiException("Could not parse routing response: " + e.getMessage());
       }
   }


   private String executeGet(String url) throws ApiException {
       Log.d("GraphHopperClient", "Executing GET: " + url);
       Request request = new Request.Builder().url(url).get().build();
       try (Response response = http.newCall(request).execute()) {
           ResponseBody rb = response.body();
           String text = rb != null ? rb.string() : "";
           if (!response.isSuccessful()) {
               Log.e("GraphHopperClient", "Response not successful: " + response.code());
               throw new ApiException(extractError(text, response.code()));
           }
           Log.d("GraphHopperClient", "Response successful");
           return text;
       } catch (IOException e) {
           Log.e("GraphHopperClient", "IO Error: " + e.getMessage(), e);
           throw new ApiException(e.getMessage() != null ? e.getMessage() : "network error");
       }
   }


   /** Pull a meaningful message out of a GraphHopper error body when possible. */
   private String extractError(String body, int code) {
       try {
           JSONObject root = new JSONObject(body);
           if (root.has("message")) {
               return "HTTP " + code + ": " + root.getString("message");
           }
       } catch (Exception ignored) {
           // fall through
       }
       return "HTTP " + code;
   }


   @SuppressWarnings("unused")
   private static String enc(String s) {
       return URLEncoder.encode(s, StandardCharsets.UTF_8);
   }
}

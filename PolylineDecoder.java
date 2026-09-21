package com.example.graphhopperapp.api;


import com.example.graphhopperapp.model.GeoPoint;


import java.util.ArrayList;
import java.util.List;


/**
* Decodes an encoded polyline string (Google's encoded polyline algorithm,
* which GraphHopper uses when points_encoded=true). Assumes 2D points
* (no elevation) which is what this app requests.
*/
public final class PolylineDecoder {


   private PolylineDecoder() {
   }


   public static List<GeoPoint> decode(String encoded) {
       List<GeoPoint> points = new ArrayList<>();
       if (encoded == null || encoded.isEmpty()) {
           return points;
       }


       int index = 0;
       int len = encoded.length();
       int lat = 0;
       int lon = 0;


       while (index < len) {
           int result = 1;
           int shift = 0;
           int b;
           do {
               b = encoded.charAt(index++) - 63 - 1;
               result += b << shift;
               shift += 5;
           } while (b >= 0x1f && index < len);
           lat += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);


           result = 1;
           shift = 0;
           do {
               b = encoded.charAt(index++) - 63 - 1;
               result += b << shift;
               shift += 5;
           } while (b >= 0x1f && index < len);
           lon += (result & 1) != 0 ? ~(result >> 1) : (result >> 1);


           points.add(new GeoPoint(lat * 1e-5, lon * 1e-5));
       }
       return points;
   }
}

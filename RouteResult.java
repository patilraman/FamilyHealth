package com.example.graphhopperapp.model;


import java.util.List;


/** The decoded result of a routing request. */
public class RouteResult {
   /** Ordered list of points forming the route geometry. */
   public final List<GeoPoint> points;
   /** Total distance in metres. */
   public final double distanceMeters;
   /** Total travel time in milliseconds. */
   public final long timeMillis;


   public RouteResult(List<GeoPoint> points, double distanceMeters, long timeMillis) {
       this.points = points;
       this.distanceMeters = distanceMeters;
       this.timeMillis = timeMillis;
   }


   /** Human-readable distance, e.g. "12.4 km" or "830 m". */
   public String formatDistance() {
       if (distanceMeters >= 1000) {
           return String.format(java.util.Locale.US, "%.1f km", distanceMeters / 1000.0);
       }
       return String.format(java.util.Locale.US, "%.0f m", distanceMeters);
   }


   /** Human-readable duration, e.g. "1 h 5 min" or "8 min". */
   public String formatDuration() {
       long totalMinutes = Math.round(timeMillis / 60000.0);
       long hours = totalMinutes / 60;
       long minutes = totalMinutes % 60;
       if (hours > 0) {
           return hours + " h " + minutes + " min";
       }
       return minutes + " min";
   }
}


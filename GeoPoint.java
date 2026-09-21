package com.example.graphhopperapp.model;


/** A simple immutable latitude/longitude pair with an optional display name. */
public class GeoPoint {
   public final double lat;
   public final double lon;
   public final String name;


   public GeoPoint(double lat, double lon, String name) {
       this.lat = lat;
       this.lon = lon;
       this.name = name;
   }


   public GeoPoint(double lat, double lon) {
       this(lat, lon, null);
   }


   @Override
   public String toString() {
       return (name != null ? name + " " : "") + "(" + lat + ", " + lon + ")";
   }
}

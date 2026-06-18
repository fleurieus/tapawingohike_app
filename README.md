# TapawingoHike App

A. **Organisatie** 

1. **Dashboard**  
   Het dashboard voor de organisatie waar teams te volgen zijn en andere onderdelen van de applicatie te bereiken zijn en/of hun informatie weergeven

2. **Route planning**  
   Het plannen van de route en distributie van de route naar de teams

3. **Team beheer**  
   Beheren van teams inclusief hun gegevens

B. **Team**

1. **Locatie updates**  
   Het doorgeven van de huidige locatie, zowel actief als passief, met of zonder extra informatie zoals een foto of tekst

2. **Route**  
   Het ontvangen en weergeven van route-onderdelen van verschillende typen

C. **Notificaties / berichten**  
   Het ontvangen/weergeven en versturen van (push-)berichten door organisatie naar team(s) of van een team naar de organisatie

  
  
  
  
## B. 2 Route

**Coördinaten**
``` 
{
    "type": "coordinate",
    "data": {
        "coordinate": {
            "latitude": 51.12345,
            "longitude": 4.56789,
            "radius": 15,
            "confirmByUser": true
        }  
    }
}
```

**Fotoroute**
``` 
{
    "type": "image",
    "data": {
        "image": "https://example.com/image.jpg",
        "zoomEnabled": true,
        "fullscreen": false,
        "coordinate": {
            "latitude": 51.12345,
            "longitude": 4.56789,
            "radius": 15,
            "confirmByUser": true
        }
    }
}
```

**Audioroute**
``` 
{
    "type": "audio",
    "data": {
        "audio": "https://example.com/audio.mp3",
        "image": "https://example.com/image.jpg",
        "showCoordinateOnMap": true,
        "coordinate": {
            "latitude": 51.12345,
            "longitude": 4.56789,
            "radius": 15,
            "confirmByUser": true
        }
    }
}
```

**Pointrush**
```
{
    "type": "pointrush",
    "data": {
        "coordinates": [
            {
                "futureTime": "2023-05-24T10:00:00",
                "coordinate": {
                    "latitude": 51.12345,
                    "longitude": 4.56789,
                    "radius": 15
                },
                "points": 10
            },
            {
                "futureTime": "2023-05-24T10:00:00",
                "coordinate": {
                    "latitude": 51.12345,
                    "longitude": 4.56789,
                    "radius": 15
                },
                "points": 10
            }
        ]
    }
}
```

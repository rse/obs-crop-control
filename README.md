
OBS-Crop-Control
================

**Remote Crop-Filter Control for OBS Studio**

About
-----

This is a small HTML5 Single-Page-Application
(SPA), running inside a Browser or directly inside a
[Source Dock](https://github.com/exeldro/obs-source-dock) of
[OBS Studio](https://obsproject.com), for interactively
controlling the position and/or size of one or more related *Crop/Pad*
source filters in [OBS Studio](https://obsproject.com) through a remote
[OBS WebSockets](https://github.com/obsproject/obs-websocket) connection.

Use Case
--------

The particular, original use-case for this application is the following:

- **High-Resolution Camera & Green-Screen**:
  You are using a high-resolution (4K, 3840x2160px) camera on front of a physical green-screen
  and you replace the green-green with the [OBS Studio](https://obsproject.com) Chroma-Key
  source filter. Behind your camera is a background image or video media.

- **Non-PTZ Camera Functionality**:
  Your camera is a non-PTZ camera or you at least cannot use the PTZ functionality
  of your camera because of the green-screen (different angles and zoom-levels would
  require the background to adjust accordingly.

- **Simulated Dynamics & Lower-Resolution Cameras**:
  You want to still somewhat simulate multiple camera angles or
  zooms by cropping various Full-HD (1920x1080px) areas out of your
  4K (3840x2160px) camera and treat those as some sort of "virtual
  cameras".

Setup
-----

The particular, original setup is the following:

- You are producing your stream or recording with
  [OBS Studio](https://obsproject.com) as your free video production software.

- You have the [OBS WebSockets](https://github.com/obsproject/obs-websocket),
  [OBS Source Dock](https://github.com/exeldro/obs-source-dock) and
  [StreamFX](https://github.com/Xaymar/obs-StreamFX) extension plugins
  installed and activated in [OBS Studio](https://obsproject.com).

- You have [OBS Studio](https://obsproject.com) configured for Full-HD
  (1920x1080px) video (see *Settings* &rarr; *Video* &rarr; *Base (Canvas) Resolution*).

- You have a scene collection in [OBS Studio](https://obsproject.com) configured,
  which contains the following additional scenes for a fictive camera named `CAM1`:

  - scene `CAM1-Full`:
      - source `CAM1-Full-FG` of type *Video Capture Device*
          - attached to your 4K camera
          - transform of *Stretch to Screen* applied
          - filter *Chrome Key* applied
      - source `CAM1-Full-BG` of type *Image*
          - attached to your 4K background image
          - transform of *Stretch to Screen* applied
  - scene `CAM1-Zoom`:
      - source `CAM1-Zoom-FG` of type *Source Mirror*
          - attached to `CAM-1-Full-FG`
          - filter *Crop/Pad* applied
      - source `CAM1-Zoom-BG` of type *Source Mirror*
          - attached to `CAM-1-Full-BG`
          - filter *Crop/Pad* applied

- You use this SPA in a separate Browser or directly from within OBS Studio
  with the help of the awesome [Source Dock](https://github.com/exeldro/obs-source-dock) plugin.
  The URL for the SPA is like the following:<br/>

  `file://[...]/index.html?[...]`<br/>
  `title=CAM1&canvas=3840x2160&preview=CAM1-Full:10`<br/>
  `&sources=CAM1-Zoom-FG,CAM1-Zoom-BG&websocket=localhost:4444`<br/>
  `&define=0:0+0/3860x2160,1:0+540/1920x1080,2:960+540/1920x1080,3:1920+540/1920x1080`<br/>

License
-------

Copyright &copy; 2021 [Dr. Ralf S. Engelschall](http://engelschall.com/)<br/>
Distributed under [GPL 3.0 license](https://spdx.org/licenses/GPL-3.0-only.html)


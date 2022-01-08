/*
**  OBS-Crop-Control ~ Remote Crop-Filter Control for OBS Studio
**  Copyright (c) 2021-2022 Dr. Ralf S. Engelschall <rse@engelschall.com>
**  Distributed under GPL 3.0 license <https://spdx.org/licenses/GPL-3.0-only.html>
*/

const app = {
    data () {
        return {
            obs:               null,
            obsStudioMode:     false,
            obsScenePreview:   "",
            obsSceneProgram:   "",
            sourceActive:      false,
            debug:             false,
            transparent:       false,
            canvasW:           0,
            canvasH:           0,
            canvasR:           0,
            sources:           [],
            defines:           [],
            title:             "",
            cropX:             0,
            cropY:             0,
            cropW:             0,
            cropH:             0,
            duration:          1000,
            fps:               30,
            previewImg:        "",
            previewShow:       false,
            previewEnabled:    false,
            dispViewportW:     0,
            dispViewportH:     0,
            dispScale:         0,
            dispCanvasW:       0,
            dispCanvasH:       0,
            dispCropCurrX:     0,
            dispCropCurrY:     0,
            dispCropCurrW:     0,
            dispCropCurrH:     0,
            dispCropNextX:     0,
            dispCropNextY:     0,
            dispCropNextW:     0,
            dispCropNextH:     0,
            dispDragPointerX:  0,
            dispDragPointerY:  0,
            dragging:          false,
            progressing:       false
        }
    },
    async mounted () {
        /*  parse options  */
        const params = {}
        for (const kv of document.location.href.replace(/^.*\?/, "").split(/\&/)) {
            const [ , key, val ] = kv.match(/^(.*?)=(.*)$/)
            params[key] = val
        }
        let m
        if (params.canvas === undefined)
            throw new Error("missing \"canvas\" parameter")
        if ((m = params.canvas.match(/^(\d+)x(\d+)$/)) === null)
            throw new Error("invalid \"canvas\" parameter")
        this.canvasW = parseInt(m[1])
        this.canvasH = parseInt(m[2])
        this.canvasR = this.canvasW / this.canvasH
        if (params.sources === undefined)
            throw new Error("missing \"sources\" parameter")
        this.sources = params.sources.split(/,/)
        if (params.websocket === undefined)
            params.websocket = "localhost:4444"
        if (params.password === undefined)
            params.password = ""
        this.title = params.title
        if (this.title === "")
            this.title = this.sources[0]
        if (params.duration !== undefined)
            this.duration = parseInt(params.duration)
        if (params.fps !== undefined)
            this.fps = parseInt(params.fps)
        if (params.debug !== undefined)
            this.debug = (params.debug === "true")
        if (params.transparent !== undefined)
            this.transparent = (params.transparent === "true")
        if (params.define !== undefined) {
            this.defines = params.define.split(/,/)
            for (let i = 0; i < this.defines.length; i++) {
                const m = this.defines[i].match(/^(\d):(\d+)\+(\d+)\/(\d+)x(\d+)$/)
                if (m === null)
                    throw new Error(`invalid define specification "${this.defines[i]}"`)
                this.defines[i] = {
                    D: m[1],
                    X: parseInt(m[2]), Y: parseInt(m[3]),
                    W: parseInt(m[4]), H: parseInt(m[5]),
                    C: false, N: false
                }
            }
        }

        /*  connect to OBS Studio  */
        this.obs = new OBSWebSocket()
        this.obs.on("error", (err) => { console.error(`OBS Studio: ERROR: ${err}`) })
        await this.obs.connect({
            address:  params.websocket,
            password: params.password,
            eventSubscriptions: 0
        })
        const version = await this.obs.send("GetVersion")
        console.log(`connected to: OBS Studio ${version.obsStudioVersion} / OBS WebSockets ${version.obsWebsocketVersion}`)

        /*  get initial cropping area  */
        const crop0 = await this.getCrop(this.sources[0])
        this.cropX = crop0.X
        this.cropY = crop0.Y
        this.cropW = crop0.W
        this.cropH = crop0.H
        for (const source of this.sources.slice(1))
            this.getCrop(source)

        /*  determine display viewport size  */
        this.dispViewportW = window.innerWidth
        this.dispViewportH = window.innerHeight
        this.dispScale     = (this.dispViewportW / this.canvasW)

        /*  determine display canvas size  */
        this.dispCanvasW = this.dispViewportW
        this.dispCanvasH = this.canvasH * this.dispScale

        /*  update display crop area  */
        this.dispCropCurrX = this.cropX * this.dispScale
        this.dispCropCurrY = this.cropY * this.dispScale
        this.dispCropCurrW = this.cropW * this.dispScale
        this.dispCropCurrH = this.cropH * this.dispScale

        /*  attach keystroke bindings  */
        for (const define of this.defines) {
            Mousetrap.bind(define.D, async () => {
                this.setDefine(define)
            })
        }

        /*  recognize changes  */
        this.onCropChange(this.sources[0], (crop) => {
            if (!(this.cropX === crop.X &&
                this.cropY === crop.Y &&
                this.cropW === crop.W &&
                this.cropH === crop.H)) {
                /*  update knowledge about OBS Studio crop area  */
                this.cropX = crop.X
                this.cropY = crop.Y
                this.cropW = crop.W
                this.cropH = crop.H

                /*  update display crop area  */
                this.dispCropCurrX = this.cropX * this.dispScale
                this.dispCropCurrY = this.cropY * this.dispScale
                this.dispCropCurrW = this.cropW * this.dispScale
                this.dispCropCurrH = this.cropH * this.dispScale
            }
        })

        /*  support source preview  */
        if (params.preview) {
            this.previewEnabled = true
            const m = params.preview.match(/^(.+):(\d+(?:\.\d+)?)$/)
            if (m === null)
                throw new Error(`invalid preview specification "${params.preview}"`)
            const [ , sourceName, fps ] = m
            const frequency = 1000 / parseFloat(fps)
            setInterval(async () => {
                if (!this.previewShow)
                    return
                const ss = await this.obs.send("TakeSourceScreenshot", {
                    sourceName: sourceName,
                    embedPictureFormat: "jpeg",
                    compressionQuality: 30,
                    width:  this.dispCanvasW,
                    height: this.dispCanvasH
                })
                this.previewImg = ss.img
            }, frequency)
        }

        /*  initially update define states  */
        this.updateDefineStates(null)

        /*  determine OBS Studio mode  */
        let result = await this.obs.send("GetStudioModeStatus")
        this.obsStudioMode = result.studioMode
        this.obs.on("StudioModeSwitched", (ev) => {
            this.obsStudioMode = ev.newState
            this.obsScenePreview = this.obsSceneProgram
        })

        /*  determine OBS Studio active scene (in preview or program)  */
        if (this.obsStudioMode) {
            result = await this.obs.send("GetCurrentScene")
            this.obsSceneProgram = result.name
            result = await this.obs.send("GetPreviewScene")
            this.obsScenePreview = result.name
        }
        else {
            result = await this.obs.send("GetCurrentScene")
            this.obsSceneProgram = result.name
            this.obsScenePreview = result.name
        }
        const updateActiveScene = async () => {
            let sourceActive = false
            for (const source of this.sources) {
                let result = await this.obs.send("GetSourceActive", { sourceName: source })
                if (result.sourceActive) {
                    sourceActive = true
                    break
                }
            }
            this.sourceActive = sourceActive
        }
        updateActiveScene()
        this.obs.on("SwitchScenes", (ev) => {
            if (this.obsStudioMode)
                this.obsSceneProgram = ev.sceneName
            else {
                this.obsScenePreview = ev.sceneName
                this.obsSceneProgram = ev.sceneName
            }
            setTimeout(() => {
                updateActiveScene()
            }, 100)
        })
        this.obs.on("PreviewSceneChanged", async (ev) => {
            if (this.obsStudioMode)
                this.obsScenePreview = ev.sceneName
        })
    },
    methods: {
        /*  callback for mouse left-click  */
        async mouseClickLeft (ev) {
            if (!this.dragging) {
                /*  start dragging  */
                if (!(ev.target === this.$refs.cropCurr || ev.target === this.$refs.cropCurrTitle))
                    return
                this.dragging = true

                /*  make crop-next start at drop-current  */
                this.dispCropNextX = this.dispCropCurrX
                this.dispCropNextY = this.dispCropCurrY
                this.dispCropNextW = this.dispCropCurrW
                this.dispCropNextH = this.dispCropCurrH

                /*  start tracking mouse position  */
                const pointerX = ev.clientX
                const pointerY = ev.clientY
                this.dispDragPointerX = pointerX
                this.dispDragPointerY = pointerY
            }
            else {
                /*  stop dragging  */
                this.dragging = false

                /*  determine old and new crop position  */
                let { x, y } = this.$refs.canvas.getBoundingClientRect()
                const cropOld = {
                    X: this.cropX,
                    Y: this.cropY,
                    W: this.cropW,
                    H: this.cropH
                }
                const cropNew = {
                    X: Math.round((this.dispCropNextX - x) / this.dispScale),
                    Y: Math.round((this.dispCropNextY - y) / this.dispScale),
                    W: Math.round(this.dispCropNextW / this.dispScale),
                    H: Math.round(this.dispCropNextH / this.dispScale)
                }
                if (cropOld.X === cropNew.X &&
                    cropOld.Y === cropNew.Y &&
                    cropOld.W === cropNew.W &&
                    cropOld.H === cropNew.H)
                    return

                /*  progress from old to new position and/or size  */
                await this.progress(cropOld, cropNew)
            }
        },

        /*  callback for mouse right-click  */
        mouseClickRight (ev) {
            if (!this.dragging)
                return
            this.dragging = false
        },

        /*  callback for mouse movement  */
        mouseMove (ev) {
            if (!this.dragging)
                return

            /*  update tracking mouse position  */
            const pointerX = ev.clientX
            const pointerY = ev.clientY
            const deltaX = pointerX - this.dispDragPointerX
            const deltaY = pointerY - this.dispDragPointerY
            this.dispDragPointerX = pointerX
            this.dispDragPointerY = pointerY

            /*  update new control crop position  */
            this.dispCropNextX += deltaX
            this.dispCropNextY += deltaY
            if (this.dispCropNextX < 0)
                this.dispCropNextX = 0
            if (this.dispCropNextX > this.dispCanvasW - this.dispCropNextW)
                this.dispCropNextX = this.dispCanvasW - this.dispCropNextW
            if (this.dispCropNextY < 0)
                this.dispCropNextY = 0
            if (this.dispCropNextY > this.dispCanvasH - this.dispCropNextH)
                this.dispCropNextY = this.dispCanvasH - this.dispCropNextH
        },

        /*  callback for mouse wheel  */
        mouseWheel (ev) {
            if (!this.dragging)
                return

            /*  resize crop  */
            this.dispCropNextH += ev.wheelDelta
            this.dispCropNextW += ev.wheelDelta * this.canvasR

            /*  restrict size to lower/upper bounds  */
            if (this.dispCropNextH < 100)
                this.dispCropNextH = 100
            if (this.dispCropNextH > this.dispCanvasH)
                this.dispCropNextH = this.dispCanvasH
            if (this.dispCropNextW < 100 * this.canvasR)
                this.dispCropNextW = 100 * this.canvasR
            if (this.dispCropNextW > this.dispCanvasW)
                this.dispCropNextW = this.dispCanvasW

            /*  optionally move position to ensure the area is still within the canvas  */
            if (0 <= this.dispCropNextX && this.dispDragPointerX <= this.dispCropNextX)
                this.dispCropNextX = this.dispDragPointerX
            if (0 <= this.dispCropNextY && this.dispDragPointerY <= this.dispCropNextY)
                this.dispCropNextY = this.dispDragPointerY
            if (this.dispCropNextX <= this.dispDragPointerX && this.dispCropNextX <= this.dispCanvasW)
                this.dispCropNextX = this.dispDragPointerX
            if (this.dispCropNextY <= this.dispDragPointerY && this.dispCropNextY <= this.dispCanvasH)
                this.dispCropNextY = this.dispDragPointerY
            if ((this.dispCropNextX + this.dispCropNextW) > this.dispCanvasW)
                this.dispCropNextX = this.dispCanvasW - this.dispCropNextW
            if ((this.dispCropNextY + this.dispCropNextH) > this.dispCanvasH)
                this.dispCropNextY = this.dispCanvasH - this.dispCropNextH
        },

        /*  animate over time  */
        animate (duration, stepper) {
            return new Promise((resolve, reject) => {
                const tick = 1000 / this.fps
                let count = 0
                const countMax = Math.floor(duration / tick)
                stepper(0)
                let timer = setInterval(() => {
                    count++
                    if (count < countMax)
                        stepper((count * tick) / duration)
                    else {
                        stepper(1)
                        clearTimeout(timer)
                        resolve()
                    }
                }, tick)
            })
        },

        /*  progress from old to new position and/or size  */
        async progress (cropOld, cropNew) {
            this.progressing = true
            await this.animate(this.duration, async (t) => {
                /*  determine new OBS Studio source crop position  */
                const v = d3.easeCubicInOut(t)
                this.cropX = cropOld.X + Math.round((cropNew.X - cropOld.X) * v)
                this.cropY = cropOld.Y + Math.round((cropNew.Y - cropOld.Y) * v)
                this.cropW = cropOld.W + Math.round((cropNew.W - cropOld.W) * v)
                this.cropH = cropOld.H + Math.round((cropNew.H - cropOld.H) * v)

                /*  determine new control crop position  */
                this.dispCropCurrX = this.cropX * this.dispScale
                this.dispCropCurrY = this.cropY * this.dispScale
                this.dispCropCurrW = this.cropW * this.dispScale
                this.dispCropCurrH = this.cropH * this.dispScale

                /*  update OBS Studio source crop settings  */
                for (const source of this.sources) {
                    const crop = await this.getCrop(source)
                    crop.X = this.cropX
                    crop.Y = this.cropY
                    crop.W = this.cropW
                    crop.H = this.cropH
                    this.setCrop(source, "", crop)
                }

                /*  update define button states  */
                this.updateDefineStates(cropNew)
            })
            this.updateDefineStates(null)
            this.progressing = false
        },

        /*  progress to a pre-defined position and/or size  */
        async setDefine (define) {
            if (this.progressing)
                return

            /*  determine old and new position and/or size  */
            const cropOld = { X: this.cropX, Y: this.cropY, W: this.cropW, H: this.cropH }
            if (cropOld.X === define.X &&
                cropOld.Y === define.Y &&
                cropOld.W === define.W &&
                cropOld.H === define.H)
                return

            /*  progress from old to new position and/or size  */
            this.dispCropNextX = define.X * this.dispScale
            this.dispCropNextY = define.Y * this.dispScale
            this.dispCropNextW = define.W * this.dispScale
            this.dispCropNextH = define.H * this.dispScale
            await this.progress(cropOld, define)
        },

        /*  determine whether a pre-defined position and/or size is current and/or next one  */
        async updateDefineStates (cropNew) {
            for (const define of this.defines) {
                define.C = (
                    this.cropX === define.X &&
                    this.cropY === define.Y &&
                    this.cropW === define.W &&
                    this.cropH === define.H
                )
                define.N = (cropNew !== null && (
                    cropNew.X === define.X &&
                    cropNew.Y === define.Y &&
                    cropNew.W === define.W &&
                    cropNew.H === define.H
                ))
            }
        },

        /*  listen to crop settings change of OBS Studio source  */
        async onCropChange (sourceName, onChange) {
            const filterName = await this.getFilterNameByType(sourceName, "crop_filter")
            let ctx = {}
            ctx.crop = this.getCrop(sourceName, filterName)
            ctx.timer = setInterval(async () => {
                if (this.progressing)
                    return
                const crop = await this.getCrop(sourceName, filterName)
                if (crop.X === ctx.crop.X &&
                    crop.Y === ctx.crop.Y &&
                    crop.W === ctx.crop.W &&
                    crop.H === ctx.crop.H)
                    return
                ctx.crop.X = crop.X
                ctx.crop.Y = crop.Y
                ctx.crop.W = crop.W
                ctx.crop.H = crop.H
                onChange(crop)
            }, 1000)
            ctx.unsubscribe = () => {
                if (ctx.timer !== null) {
                    clearTimeout(ctx.timer)
                    ctx.timer = null
                }
            }
        },

        /*  get crop settings of OBS Studio source  */
        async getFilterNameByType (sourceName, filterType) {
            const list = await this.obs.send("GetSourceFilters", { sourceName: sourceName })
            const filter = list.filters.find((filter) => filter.type === filterType)
            if (filter === undefined)
                throw new Error(`no such filter of type "${filterType}" found on source "${sourceName}"`)
            return filter.name
        },

        /*  get crop settings of OBS Studio source  */
        async getCrop (sourceName, filterName = "") {
            if (filterName === "")
                filterName = await this.getFilterNameByType(sourceName, "crop_filter")
            const info = await this.obs.send("GetSourceFilterInfo", {
                sourceName: sourceName,
                filterName: filterName
            })
            return {
                X: info.settings.left,
                Y: info.settings.top,
                W: info.settings.cx,
                H: info.settings.cy
            }
        },

        /*  set crop settings of OBS Studio source  */
        async setCrop (sourceName, filterName = "", crop) {
            if (filterName === "")
                filterName = await this.getFilterNameByType(sourceName, "crop_filter")
            const info = await this.obs.send("GetSourceFilterInfo", {
                sourceName: sourceName,
                filterName: filterName
            })
            info.settings.left = crop.X
            info.settings.top  = crop.Y
            info.settings.cx   = crop.W
            info.settings.cy   = crop.H
            await this.obs.send("SetSourceFilterSettings", {
                sourceName: sourceName,
                filterName: filterName,
                filterSettings: info.settings
            })
        }
    }
}

Vue.createApp(app).mount("body")


class BackboneAgent

  # @public
  # Metodo eseguito automaticamente all'atto della creazione dell'oggetto.
  constructor: ->
    console.debug "Backbone agent is starting..."
    @onBackboneDetected (Backbone) ->
      console.debug "Backbone detected: ", Backbone

      # note: the Backbone object might be only partially defined.
      @onceDefined Backbone, "View", @patchBackboneView
      @onceDefined Backbone, "Model", @patchBackboneModel
      @onceDefined Backbone, "Collection", @patchBackboneCollection
      @onceDefined Backbone, "Router", @patchBackboneRouter


  # UTILITY METHODS

  # @private
  # backbone agent debugging utils
  debug =
    active: false # set to true to activate debugging
    log: ->
      return unless @active
      console.log.apply console, arguments


  # @private
  # Note: null is not considered an object.
  isObject: (target) ->
    typeof target is "object" and target isnt null


  # @private
  isArray: (object) ->
    Object::toString.call(object) is "[object Array]"


  # @private
  # Returns a clone of the past.
  # NB: the sub properties will not be cloned (shallow clone).
  clone: (object) =>
    return object  unless @isObject(object)
    return object.slice()  if isArray(object)
    newObject = {}
    newObject[prop] = object[prop] for prop of object
    newObject


  # @private
  watchOnce: (object, property, callback) ->
    watch object, property, onceHandler = (prop, action, newValue, oldValue) ->
      # Unwatch doing before calling the callback (instead of doing it later)
      # You can set the property in the latter
      # Without running into an infinite loop.
      unwatch object, property, onceHandler
      callback prop, action, newValue, oldValue


  # @private
  # Perform the callback every time the property is set on the object property.
  # Note: the callback is passed the value set.
  onSetted: (object, property, callback) ->
    watch object, property, ((prop, action, newValue, oldValue) ->
      callback newValue  if action is "set"
      return
    ), 0
    return


  # @private
  # As the onSetted, but the callback is only called THE FIRST TIME that the property is set.
  onceSetted: (object, property, callback) ->
    watchOnce object, property, ((prop, action, newValue, oldValue) ->
      callback newValue  if action is "set"
      return
    ), 0
    return


  # @private
  # Monitora i set di object[property] e delle sue sottoproprietà, comprese quelle aggiunte successivamente.
  # Rileva inoltre anche le cancellazioni tramite delete delle sottoproprietà.
  # Il livello di profondità del watching è specificato da recursionLevel (come in watch.js):
  # undefined => ricorsione completa, 0 => no ricorsione (solo il livello 0), n>0 => dal livello 0 al livello n)
  onSettedDeep: (object, property, onChange, recursionLevel) ->
    watch object, property, ((prop, action, change, oldValue) ->
      onChange()  if action is "set" or action is "differentattr"
      return
    ), recursionLevel, true
    return


  # @private
  # Like onSetted, but calls the callback every time object[property] is setted to a non
  # undefined value and also immediately if it's already non-undefined.
  onDefined: (object, property, callback) ->
    callback object[property]  if object[property] isnt `undefined`
    @onSetted object, property, (newValue) ->
      callback newValue  if newValue isnt `undefined`


  # @private
  # Like onDefined, but calls the callback just once.
  onceDefined: (object, property, callback) ->
    callback object[property]  if not object[property]?
    watch object, property, handler = (prop, action, newValue, oldValue) ->
      if newValue isnt `undefined`
        unwatch object, property, handler
        callback newValue


  # @private
  # Sostituisce la funzione functionName di object con quella restituita dalla funzione patcher.
  # La funzione patcher viene chiamata con la funzione originale come argomento.
  patchFunction: (object, functionName, patcher) =>
    originalFunction = object[functionName]
    object[functionName] = patcher(originalFunction)

    # When calling onString on the patched function, call the originalFunction onString.
    # This is needed to allow an user of the originalFunction to manipulate its 
    # original string representation and not that of the patcher function.
    # NOTE: if the original function is undefined, use the string representation of the empty function.
    emptyFunction = ->

    object[functionName].toString = ->
      (if originalFunction then originalFunction.toString.apply(originalFunction, arguments) else emptyFunction.toString.apply(emptyFunction, arguments))


  # @private
  # Come patchFunction, ma aspetta che il metodo sia definito se questo è undefined al momento
  # della chiamata.
  patchFunctionLater: (object, functionName, patcher) =>
    if not object[functionName]?
      @onceDefined object, functionName, =>
        @patchFunction object, functionName, patcher
    else
      @patchFunction object, functionName, patcher


  # @private
  # Azione di un componente dell'app.
  AppComponentAction: (type, name, data, dataKind) ->
    @timestamp = new Date().getTime()
    @type = type # stringa
    @name = name # stringa
    @data = data # oggetto
    # obbligatorio se data è definito, può essere
    # - "jQuery Event": data è l'oggetto relativo ad un evento jQuery
    # - "event arguments": data è un array di argomenti di un evento Backbone
    @dataKind = dataKind

    #// Metodi di utilità ////

    # stampa nella console le informazioni sull'azione
    @printDetailsInConsole = ->

    return


  # @private
  AppComponentInfo: (category, index, component, actions) ->

    # nome del componente Backbone di cui questo componente dell'app è un discendente.
    # I valori validi sono "View", "Model", "Collection", "Router"
    @category = category

    # usato come identificatore tra tutti i componenti dell'app della sua categoria
    @index = index
    @component = component # oggetto
    @actions = actions or [] # array di oggetti AppComponentAction
    return


  # @private
  # All'atto dell'istanziazione di un componente, l'agent gli assegna
  # un indice che lo identifica all'interno dei vari array
  # riguardanti i componenti di quella categoria.
  # Tale indice viene calcolato incrementando quello dell'ultimo componente
  # della propria categoria.
  lastAppComponentsIndex =
    View: -1
    Model: -1
    Collection: -1
    Router: -1


  #// API PUBBLICA ////

  # Informazioni sui componenti dell'applicazione.
  # Hash <"componentCategory", [AppComponentInfo]>.
  # (Gli indici degli array sono quelli dei componenti.)
  @appComponentsInfo =
    View: []
    Model: []
    Collection: []
    Router: []


  # Restituisce un array con gli indici dei componenti dell'applicazione
  # della categoria specificata che sono presenti nell'app.
  @getAppComponentsIndexes = (appComponentCategory) =>
    appComponentsInfo = @appComponentsInfo[appComponentCategory]
    appComponentsIndexes = []
    for appComponentIndex of appComponentsInfo
      appComponentsIndexes.push appComponentIndex  if appComponentsInfo.hasOwnProperty(appComponentIndex)
    appComponentsIndexes


  # Restituisce l'oggetto di tipo AppComponentInfo con le informazioni sul componente dell'app passato
  # o undefined se l'oggetto passato non è un componente valido.
  @getAppComponentInfo: (appComponent) =>
    @getHiddenProperty appComponent, "appComponentInfo"


  @getAppComponentInfoByIndex: (appComponentCategory, appComponentIndex) =>
    appComponentInfo = @appComponentsInfo[appComponentCategory][appComponentIndex]
    appComponentInfo


  # Restituisce l'info della vista a cui appartiene l'elemento html passato, o undefined se non esiste.
  # L'elemento appartiene alla vista se questo combacia perfettamente con la sua proprietà el, o
  # se questa è l'ascendente più vicino rispetto a tutte le altre viste.
  @getAppViewInfoFromElement: (pageElement) =>

    # funzione che controlla se l'elemento html target è un ascendente dell'elemento html of
    isAscendant = (target, of_) ->
      return false  unless of_
      ofParent = of_.parentNode
      return true  if target is ofParent
      isAscendant target, ofParent


    # cerca il miglior candidato
    candidateViewInfo = undefined
    viewsIndexes = @getAppComponentsIndexes("View")
    i = 0
    l = viewsIndexes.length

    while i < l
      currentViewInfo = @getAppComponentInfoByIndex("View", viewsIndexes[i])
      currentView = currentViewInfo.component
      if currentView.el is pageElement

        # candidato perfetto trovato
        candidateViewInfo = currentViewInfo
        break

      # l'el di currentView è un ascendente di pageElement ed è un discendente del miglior
      # candidato trovato finora?
      candidateView = (if candidateViewInfo then candidateViewInfo.component else `undefined`)
      isBetterCandidate = isAscendant(currentView.el, pageElement) and (not candidateView or isAscendant(candidateView.el, currentView.el))

      # candidato migliore trovato
      candidateViewInfo = currentViewInfo  if isBetterCandidate
      i++
    candidateViewInfo


  #// Metodi per impostare proprietà "nascoste" all'interno degli oggetti
  #// (tipicamente usati per memorizzare l'AppComponentInfo di un dato componente dell'app
  #//  o i dati riguardanti l'initialize patchata nei componenti backbone)

  # NOTA DI SVILUPPO: non memorizzare le proprietà nascoste in oggetti contenitori
  # in quanto sarebbero condivise da tutti i cloni / istanze e sottotipi
  # (quest'ultime in caso di proprietà nascoste impostate nel prototype del tipo),
  # infatti gli oggetti sono copiati per riferimento.

  # @private
  # Prefisso dei nomi delle proprietà nascoste
  hiddenPropertyPrefix = "__backboneDebugger__"

  # @private
  getHiddenProperty: (object, property) =>
    return  unless @isObject(object)
    object[@hiddenPropertyPrefix + property]


  # @private
  setHiddenProperty: (object, property, value) =>
    return  unless @isObject(object)
    object[@hiddenPropertyPrefix + property] = value
    return


  # @private
  # instancePatcher è una funzione che viene chiamata ad ogni istanziazione del componente Backbone
  # specificato (e dei suoi sottotipi), passandogli la nuova istanza.
  # I componenti Backbone validi sono Backbone.View, Backbone.Model, Backbone.Collection e Backbone.Router
  # N.B: suppone che il componente backbone sia stato settato solo inizialmente.
  patchBackboneComponent: (BackboneComponent, instancePatcher) =>
    @onceDefined BackboneComponent, "extend", =>

      # (l'extend è l'ultimo metodo impostato, quindi ora il componente è pronto)

      # Patcha la initialize del componente (e dei suoi sottotipi) per intercettare
      # le istanze create, il meccanismo quindi funziona se i sottotipi non definiscono
      # costruttori custom che non chiamano la initialize.
      patchInitialize = (originalInitialize) =>
        =>
          # Patcha l'istanza se non è già stato fatto
          # (se ad es. l'istanza chiama l'initialize definita nel padre, evita
          # di patcharla due volte)
          isInstancePatched = @getHiddenProperty(@, "isInstancePatched")
          unless isInstancePatched
            instancePatcher @
            @setHiddenProperty @, "isInstancePatched", true
          originalInitialize.apply @, arguments  if typeof originalInitialize is "function"


      # i set/get della initialize vengono modificati in modo da patchare al volo eventuali
      # override della proprietà da parte dei sottotipi e in modo da restituire tale
      # proprietà patchata; per questo il metodo di extend usato
      # deve mantenere tali getter and setter.

      # la proprietà sarà ereditata anche dai sottotipi e finirà nelle varie istanze,
      # contiene la versione patchata della initialize
      @setHiddenProperty BackboneComponent::, "patchedInitialize", patchInitialize(BackboneComponent::initialize)
      Object.defineProperty BackboneComponent::, "initialize",
        configurable: true
        enumerable: true
        get: =>
          patchedInitialize = @getHiddenProperty(@, "patchedInitialize")
          patchedInitialize

        set: (newInitialize) =>
          @setHiddenProperty @, "patchedInitialize", @patchInitialize(newInitialize)


  # @private
  setAppComponentInfo: (appComponent, appComponentInfo) =>
    appComponentCategory = appComponentInfo.category
    appComponentIndex = appComponentInfo.index

    # salva l'appComponentInfo all'interno del componente e nell'hash pubblico apposito
    @setHiddenProperty appComponent, "appComponentInfo", appComponentInfo
    @appComponentsInfo[appComponentCategory][appComponentIndex] = appComponentInfo


  # @private
  sendMessage: (message) ->
    message.target = "page" # il messaggio riguarda la pagina
    window.postMessage message, "*"
    return


  # @private
  # Note: name is prefixed by "backboneAgent:" and can't contain spaces
  #       (because it's transformed in a Backbone event in the Panel)
  sendAppComponentReport: (name, report) ->
    # the timestamp is tipicaly used by the panel to exclude old reports
    report.timestamp = new Date().getTime()
    return


  #sendMessage({
  #    name: "backboneAgent:"+name,
  #    data: report
  #});

  # @private
  # Aggiunge il componente dell'app passato a quelli conosciuti creando l'oggetto con le info
  # e inviando un report all'esterno per informare il resto del mondo.
  # Restituisce l'indice del componente.
  registerAppComponent: (appComponentCategory, appComponent) =>

    # calcola l'indice del nuovo componente
    appComponentIndex = ++lastAppComponentsIndex[appComponentCategory]
    appComponentInfo = new AppComponentInfo(appComponentCategory, appComponentIndex, appComponent)
    @setAppComponentInfo appComponent, appComponentInfo

    # invia un report riguardante il nuovo componente dell'app
    @sendAppComponentReport appComponentCategory + ":new",
      componentIndex: appComponentIndex

    console.debug "New " + appComponentCategory, appComponent
    appComponentIndex


  # @private
  # Si mette in ascolto sui cambiamenti della proprietà e invia un report all'esterno quando accade.
  # Nota: se la proprietà inizialmente ha già un valore diverso da undefined, viene inviato subito
  # un report.
  # recursionLevel è un intero che specifica il livello di ricorsione a cui arrivare, ad es.
  # 0 è "no ricorsione", 1 è "analizza anche le proprietà di property" e così via.
  # N.B: non specificare recursionLevel equivale a dire "ricorsione completa",
  # ma attenzione a non usarla per quegli oggetti in cui potrebbero esserci cicli o si incapperà
  # in un loop infinito.
  # property may also be of the form "prop1.prop2...", stating the path to follow to reach the
  # sub-property to monitor.
  monitorAppComponentProperty: (appComponent, property, recursionLevel) =>
    # handler per il cambiamento della proprietà
    propertyChanged = =>

      # invia un report riguardante il cambiamento della proprietà
      appComponentInfo = @getAppComponentInfo(appComponent)
      @sendAppComponentReport appComponentInfo.category + ":" + appComponentInfo.index + ":change",
        componentProperty: property


      #console.debug("Property " + property + " of a " + appComponentInfo.category + " has changed: ", appComponent[property]);

    monitorFragmen = (object, propertyFragments, index) =>
      currentProperty = propertyFragments[index]
      currentRecursionLevel = (if (index is propertyFragments.length - 1) then recursionLevel else 0) # used only in last fragment
      onFragmentChange = =>

        # TODO: remove old sub setters (if any)
        if index is propertyFragments.length - 1

          # our final target has changed
          propertyChanged()

          # monitor the next fragment
        else monitorFragment object[currentProperty], propertyFragments, index + 1  if @isObject(object[currentProperty])
        return

      onFragmentChange()  if object[currentProperty] isnt `undefined`
      onSettedDeep object, currentProperty, onFragmentChange, recursionLevel
      return

    monitorFragment appComponent, property.split("."), 0


  # @private
  # Restituisce l'indice dell'azione aggiunta.
  addAppComponentAction: (appComponent, appComponentAction) =>
    appComponentInfo = @getAppComponentInfo(appComponent)
    appComponentInfo.actions.push appComponentAction
    actionIndex = appComponentInfo.actions.length - 1

    # invia un report riguardante la nuova azione
    @sendAppComponentReport appComponentInfo.category + ":" + appComponentInfo.index + ":action",
      componentActionIndex: actionIndex

    #console.debug("New action: ", appComponentAction);
    actionIndex


  # @private
  # Patcha il metodo trigger del componente dell'app.
  patchAppComponentTrigger: (appComponent) =>
    patchFunctionLater appComponent, "trigger", (originalFunction) =>
      =>
        result = originalFunction.apply(@, arguments)

        # function signature: trigger(eventName, arg1, arg2, ...)
        eventName = arguments[0]
        eventArguments = `undefined`
        # the event has arguments
        # get the event arguments by skipping the first function argument (i.e the event name)
        eventArguments = Array::slice.call(arguments, 1)  if arguments.length > 1

        # save data only if there is
        data = eventArguments
        dataKind = (if (data is `undefined`) then `undefined` else "event arguments")
        @addAppComponentAction @, new AppComponentAction("Trigger", eventName, data, dataKind)
        result


  # @private
  # Patcha la proprietà _events del componente dell'app
  # (contiene gli handler degli eventi backbone)
  patchAppComponentEvents: (appComponent) =>
  # TODO: funzione da rimuovere?

  # @private
  # Patcha il metodo sync del componente dell'app (presente in modelli e collezioni).
  patchAppComponentSync: (appComponent) =>
    @patchFunctionLater appComponent, "sync", (originalFunction) =>
      =>
        method = arguments[0] # es. "create", "read", etc.
        syncCompleted = (isSuccess) ->
          syncStatus = (if isSuccess then "success" else "failure")
          actionName = method + " (" + syncStatus + ")" # es. "fetch (failure)"
          addAppComponentAction appComponent, new AppComponentAction("Sync", actionName)
          return


        # arguments[2] è un hash con le opzioni
        # lo modifica al volo per essere informato sull'esito della sync
        argumentsArray = Array::slice.call(arguments)
        # il parametro è opzionale
        argumentsArray[2] = {}  if argumentsArray[2] is `undefined`
        @patchFunction argumentsArray[2], "success", (originalFunction) =>
          =>
            syncCompleted true
            # la proprietà è opzionale
            originalFunction.apply @, arguments  if originalFunction

        @patchFunction argumentsArray[2], "failure", (originalFunction) =>
          =>
            syncCompleted false
            # la proprietà è opzionale
            originalFunction.apply @, arguments  if originalFunction

        result = originalFunction.apply(@, argumentsArray)
        result


  # @private
  patchBackboneView: (BackboneView) =>
    console.debug "Backbone.View detected"
    @patchBackboneComponent BackboneView, (view) => # on new instance
      # registra il nuovo componente dell'app
      viewIndex = @registerAppComponent("View", view)

      # monitora i cambiamenti alle proprietà d'interesse del componente dell'app
      @monitorAppComponentProperty view, "model", 0
      @monitorAppComponentProperty view, "collection", 0
      @monitorAppComponentProperty view, "el.tagName", 0
      @monitorAppComponentProperty view, "el.id", 0
      @monitorAppComponentProperty view, "el.className", 0

      # Patcha i metodi del componente dell'app
      @patchAppComponentTrigger view
      @patchAppComponentEvents view
      @patchFunctionLater view, "delegateEvents", (originalFunction) =>
        =>
          events = arguments[0] # hash <selector, callback>

          # delegateEvents usa internamente @.events se viene chiamata senza
          # argomenti, non rendendo possibile la modifica dell'input,
          # per cui in questo caso anticipiamo il comportamento e usiamo @.events
          # come input.
          # (@.events può essere anche una funzione che restituisce l'hash)
          events = (if (typeof @events is "function") then @events() else @events)  if events is `undefined`

          # bisogna modificare al volo le callback in events
          # per poter tracciare quando vengono chiamate
          events = @clone(events) # evita di modificare l'oggetto originale
          for eventType of events
            if events.hasOwnProperty(eventType)

              # la callback può essere direttamente una funzione o il nome di una
              # funzione nella view
              callback = events[eventType]
              callback = @[callback]  unless typeof callback is "function"

              # lascia la callback non valida invariata in modo che
              # il metodo originale possa avvisare dell'errore
              continue  unless callback

              # callback valida, la modifica al volo
              # (ogni funzione ha la sua closure con i dati dell'evento)
              events[eventType] = ((eventType, callback) =>
                (event) =>

                  # event è l'evento jquery
                  @addAppComponentAction view, new AppComponentAction("Page event handling", eventType, event, "jQuery Event")
                  result = callback.apply(@, arguments)
                  result
              )(eventType, callback)

          # modifica gli argomenti (non basta settare arguments[0] in quanto non funziona
          # nella strict mode)
          argumentsArray = Array::slice.call(arguments)
          argumentsArray[0] = events
          result = originalFunction.apply(@, argumentsArray)
          result

      patchFunctionLater view, "render", (originalFunction) =>
        =>
          result = originalFunction.apply(@, arguments)
          @addAppComponentAction @, new AppComponentAction("Operation", "render")
          result

      patchFunctionLater view, "remove", (originalFunction) =>
        =>
          result = originalFunction.apply(@, arguments)
          @addAppComponentAction @, new AppComponentAction("Operation", "remove")
          result


  # @private
  patchBackboneModel: (BackboneModel) =>
    console.debug "Backbone.Model detected"
    @patchBackboneComponent BackboneModel, (model) => # on new instance
      # registra il nuovo componente dell'app
      modelIndex = registerAppComponent("Model", model)

      # monitora i cambiamenti alle proprietà d'interesse del componente dell'app
      @monitorAppComponentProperty model, "attributes", 1
      @monitorAppComponentProperty model, "id", 0
      @monitorAppComponentProperty model, "cid", 0
      @monitorAppComponentProperty model, "urlRoot", 0 # usato dal metodo url() (insieme a collection)
      @monitorAppComponentProperty model, "collection", 0

      # Patcha i metodi del componente dell'app
      @patchAppComponentTrigger model
      @patchAppComponentEvents model
      @patchAppComponentSync model


  # @private
  patchBackboneCollection: (BackboneCollection) =>
    console.debug "Backbone.Collection detected"
    @patchBackboneComponent BackboneCollection, (collection) => # on new instance
      # registra il nuovo componente dell'app
      collectionIndex = @registerAppComponent("Collection", collection)

      # monitora i cambiamenti alle proprietà d'interesse del componente dell'app
      @monitorAppComponentProperty collection, "model", 0
      @monitorAppComponentProperty collection, "models", 1
      @monitorAppComponentProperty collection, "url", 0

      # Patcha i metodi del componente dell'app
      @patchAppComponentTrigger collection
      @patchAppComponentEvents collection
      @patchAppComponentSync collection


  # @private
  patchBackboneRouter: (BackboneRouter) =>
    console.debug "Backbone.Router detected"
    @patchBackboneComponent BackboneRouter, (router) => # on new instance
      # registra il nuovo componente dell'app
      routerIndex = registerAppComponent("Router", router)

      # Patcha i metodi del componente dell'app
      @patchAppComponentTrigger router
      @patchAppComponentEvents router


  # @private
  # Calls the callback passing to it the Backbone object every time it's detected.
  # The function uses multiple methods of detection.
  onBackboneDetected: (callback) =>
    handleBackbone = (Backbone) =>

      # skip if already detected
      # (needed because the app could define Backbone in multiple ways at once)
      return  if @getHiddenProperty(Backbone, "isDetected")
      @setHiddenProperty Backbone, "isDetected", true
      callback Backbone


    # global
    @onSetted window, "Backbone", handleBackbone

    # AMD
    @patchFunctionLater window, "define", (originalFunction) =>
      =>

        # function arguments: (id? : String, dependencies? : Array, factory : Function)

        # make arguments editable
        argumentsArray = Array::slice.call(arguments)

        # find the factory function to patch it
        i = 0
        l = argumentsArray.length

        while i < l
          if typeof argumentsArray[i] is "function"

            # factory function found, patch it.
            # NOTE: in the patcher function, specify the parameters for the
            # default modules, or in case of a module with no dependencies but
            # that uses the default modules internally, the original define would see a 0-arity
            # function and would call it without them (see define() in the AMD API)
            @patchFunction argumentsArray, i, (originalFunction) =>
              (require, exports, modules) =>
                module = originalFunction.apply(@, arguments)

                # check if Backbone has been defined by the factory fuction
                # (some factories set "@" to Backbone)
                BackboneCandidate = module or @
                isBackbone = @isObject(BackboneCandidate) and typeof BackboneCandidate.View is "function" and typeof BackboneCandidate.Model is "function" and typeof BackboneCandidate.Collection is "function" and typeof BackboneCandidate.Router is "function"
                @handleBackbone BackboneCandidate  if isBackbone
                module

            break
          i++
        originalFunction.apply @, argumentsArray


window.__backboneAgent = new BackboneAgent()
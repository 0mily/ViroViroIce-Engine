function onEvent(name, v1, v2)
    if name == 'Camera Zoom' then


        local evilv1 = stringSplit(v1, ',')
        local evilnum = tonumber(evilv1[1]) or 0
        local evilsteps = tonumber(evilv1[2]) or 0
        local evilv2 = stringSplit(v2, ',')
        local evilease = stringTrim(evilv2[1] or 'linear')
        local tipo = string.lower(stringTrim(evilv2[2] or 'nll'))
        local curZoom = getProperty('defaultCamZoom')
        local evilZoom = curZoom
        local evilTime = 0

        if tipo == 'nll' then
            evilZoom = evilnum
        elseif tipo == 'mr' then
            setProperty('defaultCamZoom', getProperty('defaultCamZoom') + evilnum); -- roirbei do meu codigo antigo mesmo rsrsrsrsrs
        elseif tipo == 'lss' then
            setProperty('defaultCamZoom', getProperty('defaultCamZoom') - evilnum);
        end

        local tentofazerserminusculomaseunaoseisefuncionamasvaiassimemo = string.lower(evilease)

        if tentofazerserminusculomaseunaoseisefuncionamasvaiassimemo == 'og' then
            setProperty('defaultCamZoom', curZoom * evilZoom)
            return
        end

        

        if evilsteps > 0 then
            evilTime = evilsteps * (stepCrochet / 1000)
        end

        doTweenZoom('camZoomTween', 'camGame', evilZoom, evilTime, evilease)
    end
end

function onTweenCompleted(tag, vars)
    
    if tag == 'camZoomTween' then
        setProperty('defaultCamZoom', getProperty('camGame.zoom')) -- pra camera não voltar pro lugar original quando o tween acabar
    end
end
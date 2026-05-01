function onCreatePost()
    if getPropertyFromClass('backend.ClientPrefs', 'data.modchart') then
        for i = 4, 7 do
            setPropertyFromGroup('strumLineNotes', i, 'x', 420 + (i - 4) * 112)
        end

        for i = 0,3 do
            setPropertyFromGroup('strumLineNotes',i,'x',-500)--listen i don't fucking care just get invisible freak
        end
    end
end
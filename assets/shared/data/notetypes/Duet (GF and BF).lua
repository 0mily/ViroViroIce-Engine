function goodNoteHit(index, noteData, noteType, isSustain)
	if noteType == 'Duet (GF and BF)' then
		playAnim('gf', getProperty('singAnimations['..noteData..']'), true)
		setProperty('gf.specialAnim', true)
	end
end
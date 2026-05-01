import modchart.Manager;

var modchartManager:modchart.Manager;

function onCreatePost() {
    modchartManager = new modchart.Manager();
    add(modchartManager);


    for (strum in playerStrums) {
        strum.cameras = [camHUD];
    }
    for (strum in opponentStrums) {
        strum.cameras = [camHUD];
    }


    // adiciona o modifier






    modchartManager.addModifier("drunk", -1);

    // já deixa ativo direto
    modchartManager.setPercent("drunk", 0.5, -1); // muda esse valor pra intensidade
}
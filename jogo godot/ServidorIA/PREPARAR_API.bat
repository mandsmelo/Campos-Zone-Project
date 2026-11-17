@echo off
cd /d "%~dp0"
py -3 -m venv .venv
if errorlevel 1 goto erro
.venv\Scripts\python.exe -m pip install -r requirements.txt
if errorlevel 1 goto erro
.venv\Scripts\python.exe -c "from chatbot.indexacao import executar_indexacao; executar_indexacao()"
if errorlevel 1 goto erro
rem Treina com o CSV do repositorio na mesma versao de sklearn instalada.
.venv\Scripts\python.exe regressao\treinamento.py
if errorlevel 1 goto erro
echo Preparacao concluida. Execute INICIAR_API.bat.
pause
exit /b 0
:erro
echo Falha na preparacao. Leia a mensagem acima. Verifique Python 64 bits e internet.
pause
exit /b 1

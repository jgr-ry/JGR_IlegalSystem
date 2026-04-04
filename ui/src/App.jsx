import React, { useState, useEffect } from 'react';
import Step1Config from './components/Step1Config';
import Step3Specialization from './components/Step3Specialization';
import Step4Finalize from './components/Step4Finalize';

function App() {
    const [visible, setVisible] = useState(false);
    const [step, setStep] = useState(0);
    const [config, setConfig] = useState({});
    const [specializations, setSpecializations] = useState({});
    const [translations, setTranslations] = useState({});
    const [gangData, setGangData] = useState({});

    useEffect(() => {
        const handleMessage = (event) => {
            const { action, config: setupConfig, specializations: specs } = event.data;

            if (action === 'open_gang_creator') {
                setConfig(setupConfig);
                setTranslations(setupConfig?.Translations || {});
                setStep(1);
                setVisible(true);
            } else if (action === 'open_specialization_step') {
                setSpecializations(specs);
                setStep(3);
                setVisible(true);
            }
        };

        window.addEventListener('message', handleMessage);

        // For browser testing without FiveM
        if (!window.invokeNative) {
            window.postMessage({
                action: 'open_gang_creator',
                config: {
                    BasePermissions: { full_access: "Acceso Total", stash: "Almacén" },
                    Specializations: { weed: "Hierba", meth: "Metanfetamina", wpns: "Armas", coke: "Cocaína" },
                    Translations: {
                        ui_title: "CREAR TU ORGANIZACIÓN", ui_subtitle: "Configura los aspectos esenciales.",
                        ui_org_name: "NOMBRE DE LA ORGANIZACIÓN", ui_ranks: "RANGOS", ui_permissions: "PERMISOS",
                        ui_cancel: "CANCELAR", ui_continue: "CONTINUAR",
                        ui_spec_title: "ELIJA LA ESPECIALIZACIÓN DE SU ORGANIZACIÓN", ui_spec_subtitle: "Elija uno de los cuatro objetivos para determinar la especialización de su organización",
                        ui_finish_title: "TU ORGANIZACIÓN HA SIDO CREADA", ui_finish_desc: "Su organización se ha creado con éxito. Haga clic en finalizar para acceder a toda la gerencia de su negocio, donde puede comenzar a reclutar personal, adquirir actualizaciones y mucho más.",
                        ui_finish_btn: "FINALIZAR"
                    }
                }
            }, "*");
        }

        return () => window.removeEventListener('message', handleMessage);
    }, []);

    const handleClose = () => {
        setVisible(false);
        fetch(`https://${window.GetParentResourceName()}/closeUI`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({})
        }).catch(e => console.log(e));
    };

    const handleStep1Complete = (data) => {
        setGangData({ ...gangData, config: data });
        setVisible(false); // Hide window for generic ped placement
        fetch(`https://${window.GetParentResourceName()}/step1_config_complete`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify(data)
        }).catch(e => console.log(e));
    };

    const handleStep3Complete = (spec) => {
        setGangData({ ...gangData, specialization: spec });
        setStep(4);
    };

    const handleFinish = () => {
        fetch(`https://${window.GetParentResourceName()}/finishCreation`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json; charset=UTF-8' },
            body: JSON.stringify({ specialization: gangData.specialization })
        }).catch(e => console.log(e));
        setVisible(false);
        setStep(0);
    };

    if (!visible) return null;

    return (
        <div style={{ width: '100%', height: '100%', background: 'rgba(10, 15, 30, 0.95)', color: 'white', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
            {step === 1 && <Step1Config config={config} translations={translations} onComplete={handleStep1Complete} onClose={handleClose} />}
            {step === 3 && <Step3Specialization specializations={specializations} translations={translations} onComplete={handleStep3Complete} />}
            {step === 4 && <Step4Finalize translations={translations} onFinish={handleFinish} />}
        </div>
    );
}

export default App;

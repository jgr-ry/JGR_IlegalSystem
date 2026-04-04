import React from 'react';

export default function Step4Finalize({ translations, onFinish }) {
    return (
        <div style={{ width: '60%', background: 'rgba(0,0,0,0.5)', padding: '40px', borderRadius: '10px', textAlign: 'center' }}>
            <h1>{translations?.ui_finish_title || "TU ORGANIZACIÓN HA SIDO CREADA"}</h1>
            <div style={{ fontSize: '100px', margin: '20px 0' }}>🕴️</div>
            <p style={{ fontSize: '18px', lineHeight: '1.5', marginBottom: '30px' }}>
                {translations?.ui_finish_desc || "Su organización se ha creado con éxito. Haga clic en finalizar para acceder a toda la gerencia de su negocio, donde puede comenzar a reclutar personal, adquirir actualizaciones y mucho más."}
            </p>

            <button
                onClick={onFinish}
                style={{
                    padding: '15px 40px',
                    background: 'white',
                    color: 'black',
                    border: 'none',
                    fontWeight: 'bold',
                    fontSize: '20px',
                    cursor: 'pointer'
                }}>
                {translations?.ui_finish_btn || "FINALIZAR"}
            </button>
        </div>
    );
}

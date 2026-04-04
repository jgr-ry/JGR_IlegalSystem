import React, { useState } from 'react';

export default function Step3Specialization({ specializations, translations, onComplete }) {
    const [selected, setSelected] = useState(null);

    return (
        <div style={{ width: '80%', background: 'rgba(0,0,0,0.5)', padding: '20px', borderRadius: '10px', textAlign: 'center' }}>
            <h1>{translations?.ui_spec_title || "ELIJA LA ESPECIALIZACIÓN DE SU ORGANIZACIÓN"}</h1>
            <p>{translations?.ui_spec_subtitle || "Elija uno de los cuatro objetivos para determinar la especialización de su organización"}</p>

            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '20px', marginTop: '20px' }}>
                {specializations && Object.entries(specializations).map(([key, label]) => (
                    <div
                        key={key}
                        onClick={() => setSelected(key)}
                        style={{
                            padding: '40px',
                            background: selected === key ? 'rgba(255, 255, 255, 0.4)' : 'rgba(0,0,0,0.7)',
                            cursor: 'pointer',
                            borderRadius: '10px',
                            border: selected === key ? '2px solid white' : '2px solid transparent',
                            transition: 'all 0.2s',
                            fontWeight: 'bold',
                            fontSize: '20px'
                        }}>
                        {label}
                    </div>
                ))}
            </div>

            <div style={{ marginTop: '30px' }}>
                <button
                    onClick={() => selected && onComplete(selected)}
                    disabled={!selected}
                    style={{
                        padding: '15px 30px',
                        background: selected ? 'white' : 'gray',
                        color: 'black',
                        border: 'none',
                        fontWeight: 'bold',
                        fontSize: '18px',
                        cursor: selected ? 'pointer' : 'not-allowed'
                    }}>
                    {translations?.ui_continue || "CONTINUAR"}
                </button>
            </div>
        </div>
    );
}

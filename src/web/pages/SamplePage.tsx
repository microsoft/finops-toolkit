import Sidebar from '../components/Sidebar';
import TopMenuBar from '../components/TopMenuBar';

export function SamplePage() {
    return (
        <div
            data-testid="sample-page-root" // Root container for the page
            style={{ 
                display: 'flex', 
                flexDirection: 'column', 
                height: '100vh', 
                width: '100%', 
                overflowX: 'hidden', 
                backgroundColor: '#f4f6f8', 
                boxSizing: 'border-box' // Ensure no extra space
            }}
        >
            {/* TopMenuBar rendered at the top without shrinking */}
            <div style={{ flexShrink: 0, width: '100%' }}>
                <TopMenuBar />
            </div>
            <div style={{ display: 'flex', flexGrow: 1, overflow: 'hidden', width: '100%' }}>
                <Sidebar />
                <div
                    data-testid="main-content" // Added this line for test targeting
                    style={{
                        flexGrow: 1,
                        display: 'flex',
                        alignContent: 'center', 
                        alignItems: 'center', 
                        flexDirection: 'column', 
                        overflowY: 'auto',
                        overflowX: 'hidden', 
                        backgroundColor: '#ffffff',
                        borderTopLeftRadius: '12px',
                        boxShadow: '0px 4px 8px rgba(0, 0, 0, 0.1)',
                        padding: '20px',
                        margin: '0',
                        width: '100%', // Ensure full width
                        boxSizing: 'border-box', // Include padding and border in width calculation
                    }}
                >
                    <main style={{ padding: '20px', flexGrow: 1 }}>
                        <h1>SamplePage</h1>
                        {/* Add your components or content here */}
                    </main>
                </div>
            </div>
        </div>
    );
}

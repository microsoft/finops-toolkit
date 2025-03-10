import { useState } from 'react';
import {
    Text,
    Caption1,
    Link,
    Card,
    Image,
    makeStyles,
    tokens,
} from "@fluentui/react-components";
import { ArrowRight16Regular } from "@fluentui/react-icons";

const catalogItems = [
    {
        icon: "/finopshubs.svg",
        title: "FinOps hubs",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "powerbi.svg",
        title: "Power BI",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/costopt.svg",
        title: "Cost optimization",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/costopt.svg",
        title: "Governance",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "powershell.svg",
        title: "PowerShell commands",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/tools.svg",
        title: "Bicep modules",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/tools.svg",
        title: "Azure Optimization Engine",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/opendata.svg",
        title: "Open and sample data",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    },
    {
        icon: "/learning.svg",
        title: "Learning",
        description: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Morbi luctus.",
    }
];

const useStyles = makeStyles({
    modelCatalog: {
        display: 'flex',
        flexDirection: 'column',
        padding: '0 16px',
        margin: '32px 18px',
        gap: '24px',
    },
    catalogTitle: {
        color: tokens.colorNeutralForeground1,
        fontWeight: tokens.fontWeightSemibold,
        fontSize: tokens.fontSizeBase600,
    },
    catalogGrid: {
        display: 'grid',
        gap: '16px',
        gridTemplateColumns: 'repeat(4, 1fr)',

        '@media (max-width: 1200px)': {
            gridTemplateColumns: 'repeat(3, 1fr)',
            display: 'flex',
            flexDirection: 'column',
            overflowX: 'hidden',
        },
        '@media (max-width: 768px)': {
            gridTemplateColumns: 'repeat(2, 1fr)',
            display: 'flex',
            flexDirection: 'column',
            overflowX: 'hidden',
        },
        '@media (max-width: 480px)': {
            gridTemplateColumns: 'repeat(1, 1fr)',
            display: 'flex',
            flexDirection: 'column',
            overflowX: 'hidden',
        },

    },
    cardWrapper: {
        display: 'flex',
        flexDirection: 'column',
        padding: '18px',
        backgroundColor: tokens.colorNeutralBackground1,
        borderRadius: '12px',
        border: `1px solid ${tokens.colorNeutralStroke2}`,
        boxShadow: tokens.shadow2,
        cursor: 'pointer',
        height: '138px',
        width: '100%',
        position: 'relative',
        overflow: 'hidden',
        transition: 'all ease-out 0.1s',
        '&:hover': {
            backgroundColor: tokens.colorNeutralBackground1Hover,
            border: '2px solid transparent', 
            background: `linear-gradient(white, white) padding-box, linear-gradient(45deg, #992FB6, #38bdf8) border-box`,
            boxShadow: tokens.shadow4,
        },
    },
    cardContent: {
        display: 'flex',
        alignItems: 'flex-start',
        gap: '16px',
    },
    textSection: {
        flexGrow: 1,
        display: 'flex',
        gap: '4px',
        flexDirection: 'column',
    },
    catalogLink: {
        color: tokens.colorBrandForegroundLink,
        opacity: 0,
        marginTop: '4px',
        transition: 'opacity 0.1s ease',
        display: 'flex',
        gap: '2px',
        alignItems: 'center',
        '&:hover': {
            opacity: 1,
            textDecoration: 'None',
        },
    },
    arrowIcon: {
        color: tokens.colorBrandForegroundLink
    },
});

const ToolsCatalog = () => {
    const styles = useStyles();
    const [hoveredIndex, setHoveredIndex] = useState<number | null>(null);

    return (
        <section className={styles.modelCatalog}>
            <Text size={600}  weight="semibold" className={styles.catalogTitle}>Automate and extend the Microsoft cloud</Text>
            <div className={styles.catalogGrid}>
                {catalogItems.map((item, index) => (
                    <Card
                        className={styles.cardWrapper}
                        key={index}
                        onMouseEnter={() => setHoveredIndex(index)}
                        onMouseLeave={() => setHoveredIndex(null)}
                    >
                        <div className={styles.cardContent}>
                            <Image src={item.icon} alt={item.title} width={32} height={32} />
                            <div className={styles.textSection}>
                                <Text weight="semibold">{item.title}</Text>
                                <Caption1>{item.description}</Caption1>
                                <Link
                                    href="#"
                                    className={styles.catalogLink}
                                    style={{ opacity: hoveredIndex === index ? 1 : 0 }}
                                >
                                    View details
                                    <ArrowRight16Regular className={styles.arrowIcon} />
                                </Link>
                            </div>
                        </div>
                    </Card>
                ))}
            </div>
        </section>
    );
};

export default ToolsCatalog;